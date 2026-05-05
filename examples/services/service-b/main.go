package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func parseOTLPEndpoint(raw string) (hostport string, err error) {
	if raw == "" {
		return "", fmt.Errorf("empty OTLP endpoint")
	}
	ep := strings.TrimSpace(raw)
	ep = strings.TrimPrefix(ep, "http://")
	ep = strings.TrimPrefix(ep, "https://")
	if ep == "" {
		return "", fmt.Errorf("invalid OTLP endpoint")
	}
	return ep, nil
}

func setupOTel(ctx context.Context, serviceName string) (shutdown func(context.Context) error, err error) {
	raw := strings.TrimSpace(os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
	if raw == "" {
		raw = "localhost:4318"
	}
	ep, err := parseOTLPEndpoint(raw)
	if err != nil {
		return nil, err
	}

	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String(serviceName),
		),
	)
	if err != nil {
		return nil, err
	}

	traceExporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(ep),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	metricExporter, err := otlpmetrichttp.New(ctx,
		otlpmetrichttp.WithEndpoint(ep),
		otlpmetrichttp.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter)),
		sdkmetric.WithResource(res),
	)

	otel.SetTracerProvider(tracerProvider)
	otel.SetMeterProvider(meterProvider)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return func(c context.Context) error {
		me := tracerProvider.Shutdown(c)
		mo := meterProvider.Shutdown(c)
		switch {
		case me != nil && mo != nil:
			return fmt.Errorf("trace shutdown: %v; meter shutdown: %v", me, mo)
		case me != nil:
			return me
		default:
			return mo
		}
	}, nil
}

func main() {
	serviceName := os.Getenv("OTEL_SERVICE_NAME")
	if serviceName == "" {
		serviceName = "service-b"
	}

	addr := strings.TrimSpace(os.Getenv("SERVICE_B_PORT"))
	if addr == "" {
		addr = ":8082"
	}

	serviceAURL := strings.TrimSuffix(strings.TrimSpace(os.Getenv("SERVICE_A_URL")), "/")
	if serviceAURL == "" {
		serviceAURL = "http://localhost:8081"
	}

	ctx := context.Background()
	shutdown, err := setupOTel(ctx, serviceName)
	if err != nil {
		log.Fatalf("otel: %v", err)
	}

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(otelgin.Middleware(serviceName))

	client := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   15 * time.Second,
	}
	meter := otel.Meter(serviceName)
	processedCounter, _ := meter.Int64Counter("omniscope_processed_messages_total", metric.WithDescription("Total processed OmniScope messages"))
	errorCounter, _ := meter.Int64Counter("omniscope_processing_errors_total", metric.WithDescription("Total processing errors in OmniScope handlers"))

	r.GET("/health", func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	r.GET("/hello-b", func(c *gin.Context) {
		processedCounter.Add(c.Request.Context(), 1, metric.WithAttributes(attribute.String("route", "/hello-b"), attribute.String("service", serviceName)))
		c.JSON(http.StatusOK, gin.H{"message": "hello from service-b"})
	})

	r.GET("/call-a", func(c *gin.Context) {
		req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, serviceAURL+"/hello-a", nil)
		if err != nil {
			errorCounter.Add(c.Request.Context(), 1, metric.WithAttributes(attribute.String("route", "/call-a"), attribute.String("service", serviceName)))
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		resp, err := client.Do(req)
		if err != nil {
			errorCounter.Add(c.Request.Context(), 1, metric.WithAttributes(attribute.String("route", "/call-a"), attribute.String("service", serviceName)))
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)
		if resp.StatusCode != http.StatusOK {
			errorCounter.Add(c.Request.Context(), 1, metric.WithAttributes(attribute.String("route", "/call-a"), attribute.String("service", serviceName)))
			c.JSON(resp.StatusCode, gin.H{"error": string(body)})
			return
		}
		processedCounter.Add(c.Request.Context(), 1, metric.WithAttributes(attribute.String("route", "/call-a"), attribute.String("service", serviceName)))
		c.JSON(http.StatusOK, gin.H{"via": "service-b", "from_a": strings.TrimSpace(string(body))})
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Printf("%s listening on %s\n", serviceName, addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	sdCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_ = srv.Shutdown(sdCtx)
	if err := shutdown(sdCtx); err != nil {
		log.Printf("otel shutdown: %v", err)
	}
}
