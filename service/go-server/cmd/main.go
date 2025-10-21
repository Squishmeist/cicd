package main

import (
	"fmt"
	"log"
	"net/http"

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

	server := &http.Server{
		Addr:    ":8080",
		Handler: e,
	}

	fmt.Println("Starting server on :8080")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("echo server error: %v", err)
	}
}
