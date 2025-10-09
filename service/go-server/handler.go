package goServer

import (
	"fmt"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/redis/go-redis/v9"
	api "github.com/squishmeist/cicd/api/gen"
)

type Handler struct {
	Redis *redis.Client
}

func (h *Handler) GetHealth(ctx echo.Context) error {
	fmt.Println("Handling GetHealth request")
	reqCtx := ctx.Request().Context()
	if err := h.Redis.Ping(reqCtx).Err(); err != nil {
		return ctx.JSON(http.StatusServiceUnavailable, api.HealthResponse{
			Status: "unhealthy",
		})
	}
	return ctx.JSON(http.StatusOK, api.HealthResponse{
		Status: "ok",
	})
}
