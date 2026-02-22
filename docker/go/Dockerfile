# Builder Stage: Build the Go application
FROM golang:1.22-alpine AS builder

# Install git (if needed for dependencies)
RUN apk add --no-cache git

# Set the working directory
WORKDIR /app

# Copy go.mod to download dependencies first (for better caching)
COPY app-go/go.mod ./

# Download Go dependencies
RUN go mod download

# Copy the rest of the source code
COPY app-go/ .

# Build the Go application statically
RUN CGO_ENABLED=0 GOOS=linux go build -o go-api .

# Final Stage: Create a minimal runtime image
FROM alpine:3.19

# Install CA certificates for HTTPS requests
RUN apk add --no-cache ca-certificates

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set the working directory
WORKDIR /app

# Copy the built binary from the builder stage
COPY --from=builder /app/go-api .

# Switch to the non-root user
USER appuser

# Expose the port the app runs on
EXPOSE 8080

# Run the application
CMD ["./go-api"]
