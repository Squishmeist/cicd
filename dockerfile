# Build stage
FROM golang:1.20-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o server main.go

# Run stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/server .
EXPOSE 8080
CMD ["./server"]
