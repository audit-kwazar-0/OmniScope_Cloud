# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
COPY main.go ./
RUN go mod download
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /service-a .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=builder /service-a /service-a
ENV SERVICE_A_PORT=:8081
EXPOSE 8081
ENTRYPOINT ["/service-a"]
