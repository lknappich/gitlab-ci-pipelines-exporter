FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gitlab-ci-pipelines-exporter ./cmd/gitlab-ci-pipelines-exporter

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/gitlab-ci-pipelines-exporter .

# Copy web frontend files
COPY web/ /web/

# Create a simple script to serve both API and frontend
RUN cat > serve.sh << 'EOF'
#!/bin/sh
# Start the exporter in background
./gitlab-ci-pipelines-exporter run --config /etc/config.yml &

# Simple HTTP server for frontend (if needed)
# Note: The exporter itself can serve static files if configured
wait
EOF

RUN chmod +x serve.sh

# Expose port
EXPOSE 8080

# Default command
CMD ["./gitlab-ci-pipelines-exporter", "run", "--config", "/etc/config.yml"]
