package main

import (
	"log"

	"github.com/familyhealth/server/internal/config"
	"github.com/familyhealth/server/internal/handler"
	"github.com/familyhealth/server/internal/middleware"
	"github.com/familyhealth/server/internal/model"
	"github.com/familyhealth/server/internal/repository"
	"github.com/familyhealth/server/internal/service"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	// Load config
	cfg := config.Load()

	// Logger
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	// Database
	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect database: %v", err)
	}

	// Auto-migrate
	if err := db.AutoMigrate(
		&model.User{},
		&model.HealthReport{},
		&model.ReportFile{},
		&model.MedicalCase{},
		&model.Medication{},
		&model.CaseAttachment{},
		&model.FamilyGroup{},
		&model.FamilyMember{},
		&model.FamilyInvite{},
		&model.ChatConversation{},
		&model.ChatMessage{},
	); err != nil {
		log.Fatalf("failed to migrate: %v", err)
	}

	// Enable pgvector extension
	db.Exec("CREATE EXTENSION IF NOT EXISTS vector")

	// Repositories
	repos := &repository.Repositories{
		User:        repository.NewUserRepo(db),
		Report:      repository.NewReportRepo(db),
		MedicalCase: repository.NewCaseRepo(db),
		Family:      repository.NewFamilyRepo(db),
		Chat:        repository.NewChatRepo(db),
	}

	// Services
	services := &service.Services{
		Auth:   service.NewAuthService(repos, cfg),
		Report: service.NewReportService(repos),
		Case:   service.NewCaseService(repos),
		Family: service.NewFamilyService(repos),
		AI:     service.NewAIService(cfg),
	}

	// Handlers
	handlers := &handler.Handlers{
		Auth:   handler.NewAuthHandler(services),
		Report: handler.NewReportHandler(services),
		Case:   handler.NewCaseHandler(services),
		Family: handler.NewFamilyHandler(services),
		AI:     handler.NewAIHandler(services, cfg),
	}

	// Router
	r := gin.Default()
	r.Use(middleware.CORS())

	api := r.Group("/api/v1")
	{
		// Auth (public)
		auth := api.Group("/auth")
		auth.POST("/sms-code", handlers.Auth.SendSMSCode)
		auth.POST("/login", handlers.Auth.Login)

		// AI Proxy (public — no JWT required)
		ai := api.Group("/ai")
		ai.POST("/proxy", handlers.AI.Proxy)

		// Protected routes
		protected := api.Group("")
		protected.Use(middleware.JWTAuth(cfg.JWTSecret))
		{
			// Users
			protected.GET("/users/me", handlers.Auth.GetMe)
			protected.PUT("/users/me", handlers.Auth.UpdateMe)

			// Reports
			protected.POST("/reports", handlers.Report.Create)
			protected.GET("/reports", handlers.Report.List)
			protected.GET("/reports/:id", handlers.Report.Get)
			protected.DELETE("/reports/:id", handlers.Report.Delete)
			protected.POST("/reports/:id/analyze", handlers.AI.AnalyzeReport)

			// Medical Cases
			protected.POST("/cases", handlers.Case.Create)
			protected.GET("/cases", handlers.Case.List)
			protected.GET("/cases/:id", handlers.Case.Get)
			protected.DELETE("/cases/:id", handlers.Case.Delete)

			// Family Groups
			protected.POST("/families", handlers.Family.Create)
			protected.GET("/families", handlers.Family.List)
			protected.GET("/families/:id", handlers.Family.Get)
			protected.DELETE("/families/:id", handlers.Family.Delete)
			protected.POST("/families/:id/invite", handlers.Family.Invite)
			protected.POST("/families/:id/qrcode", handlers.Family.GenerateQRCode)
			protected.POST("/families/join", handlers.Family.Join)
			protected.GET("/families/:id/reports", handlers.Family.MemberReports)

			// AI Chat
			protected.POST("/ai/chat", handlers.AI.Chat)
			protected.GET("/ai/conversations", handlers.AI.ListConversations)
			protected.DELETE("/ai/conversations/:id", handlers.AI.DeleteConversation)
		}
	}

	// Health check
	r.GET("/health", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

	addr := ":" + cfg.Port
	logger.Info("server starting", zap.String("addr", addr))
	if err := r.Run(addr); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
