package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/redis/go-redis/v9"
	goServer "github.com/squishmeist/cicd"
	apibase "github.com/squishmeist/cicd/api"
	apigen "github.com/squishmeist/cicd/api/gen"
)

func main() {
	cfg, err := goServer.LoadConfig()
	if err != nil {
		log.Fatalf("failed to load configuration: %v", err)
	}

	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Addr,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	defer rdb.Close()

	e := echo.New()
	handler := &goServer.Handler{
		Redis: rdb,
	}
	apigen.RegisterHandlers(e, handler)

	e.GET("/openapi.yaml", func(c echo.Context) error {
		return c.Blob(http.StatusOK, "application/yaml", apibase.OpenAPISpec())
	})
	docsHandler := func(c echo.Context) error {
		return c.HTMLBlob(http.StatusOK, apibase.SwaggerHTML("/openapi.yaml"))
	}
	e.GET("/docs", docsHandler)
	e.GET("/docs/*", docsHandler)

	fmt.Println("Starting server on :8080")
	startServer(e)
}

func startServer(e *echo.Echo) {
	// Graceful shutdown handling
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	server := &http.Server{
		Addr:    ":8080",
		Handler: e,
	}

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("echo server error: %v", err)
		}
	}()

	<-quit
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("error during server shutdown: %v", err)
	}
}
