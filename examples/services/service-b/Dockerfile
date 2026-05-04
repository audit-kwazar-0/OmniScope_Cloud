# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
COPY main.go ./
RUN go mod download
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /service-b .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=builder /service-b /service-b
ENV SERVICE_B_PORT=:8082
EXPOSE 8082
ENTRYPOINT ["/service-b"]
