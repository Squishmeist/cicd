package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/spf13/viper"
)

func main() {
	// Initialise Viper
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("/etc/conf")

	// Read the config file
	if err := viper.ReadInConfig(); err != nil {
		panic(fmt.Errorf("fatal error reading config file: %w", err))
	}

	// Get Redis configuration
	redisAddr := viper.GetString("redis.addr")
	redisPassword := viper.GetString("redis.password")
	redisDB := viper.GetInt("redis.db")

	// Initialize Redis client
	rdb := redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: redisPassword,
		DB:       redisDB,
	})

	ctx := context.Background()

	// Set up a channel to listen for OS signals
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-stop
		fmt.Println("Shutting down...")
		rdb.Close() // Close Redis client on shutdown
		os.Exit(0)
	}()

	val, err := rdb.Get(ctx, "key").Result()
	if err != nil {
		fmt.Print("Error getting key:", err)
		return
	}
	fmt.Println("key:", val)

	for {
		fmt.Println("Application is running...")
		time.Sleep(10 * time.Second)
	}
}
