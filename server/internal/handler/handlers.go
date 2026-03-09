package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/familyhealth/server/internal/config"
	"github.com/familyhealth/server/internal/middleware"
	"github.com/familyhealth/server/internal/model"
	"github.com/familyhealth/server/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handlers struct {
	Auth   *AuthHandler
	Report *ReportHandler
	Case   *CaseHandler
	Family *FamilyHandler
	AI     *AIHandler
}

// ============ Auth Handler ============

type AuthHandler struct{ svc *service.Services }

func NewAuthHandler(svc *service.Services) *AuthHandler { return &AuthHandler{svc: svc} }

func (h *AuthHandler) SendSMSCode(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	// TODO: integrate SMS provider
	c.JSON(http.StatusOK, gin.H{"expires_in": 300})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
		Code  string `json:"code"`
		Name  string `json:"name"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	// TODO: verify SMS code from Redis

	user, token, isNew, err := h.svc.Auth.LoginOrRegister(req.Phone, req.Name)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": token, "user": user, "is_new": isNew})
}

func (h *AuthHandler) GetMe(c *gin.Context) {
	userID := middleware.GetUserID(c)
	user, err := h.svc.Auth.GetUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	c.JSON(http.StatusOK, user)
}

func (h *AuthHandler) UpdateMe(c *gin.Context) {
	userID := middleware.GetUserID(c)
	user, err := h.svc.Auth.GetUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	if err := c.ShouldBindJSON(user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	h.svc.Auth.UpdateUser(user)
	c.JSON(http.StatusOK, user)
}

// ============ Report Handler ============

type ReportHandler struct{ svc *service.Services }

func NewReportHandler(svc *service.Services) *ReportHandler { return &ReportHandler{svc: svc} }

func (h *ReportHandler) Create(c *gin.Context) {
	var report model.HealthReport
	if err := c.ShouldBindJSON(&report); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	report.UploaderID = middleware.GetUserID(c)
	if report.UserID == uuid.Nil {
		report.UserID = report.UploaderID
	}

	if err := h.svc.Report.Create(&report); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, report)
}

func (h *ReportHandler) List(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if uid := c.Query("user_id"); uid != "" {
		userID, _ = uuid.Parse(uid)
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))

	reports, total, err := h.svc.Report.List(userID, page, size)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": reports, "total": total, "page": page})
}

func (h *ReportHandler) Get(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	report, err := h.svc.Report.Get(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "report not found"})
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h *ReportHandler) Delete(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	if err := h.svc.Report.Delete(id, middleware.GetUserID(c)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ============ Case Handler ============

type CaseHandler struct{ svc *service.Services }

func NewCaseHandler(svc *service.Services) *CaseHandler { return &CaseHandler{svc: svc} }

func (h *CaseHandler) Create(c *gin.Context) {
	var mc model.MedicalCase
	if err := c.ShouldBindJSON(&mc); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	mc.UploaderID = middleware.GetUserID(c)
	if mc.UserID == uuid.Nil {
		mc.UserID = mc.UploaderID
	}

	if err := h.svc.Case.Create(&mc); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, mc)
}

func (h *CaseHandler) List(c *gin.Context) {
	userID := middleware.GetUserID(c)
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))

	cases, total, err := h.svc.Case.List(userID, page, size)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": cases, "total": total, "page": page})
}

func (h *CaseHandler) Get(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	mc, err := h.svc.Case.Get(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "case not found"})
		return
	}
	c.JSON(http.StatusOK, mc)
}

func (h *CaseHandler) Delete(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	if err := h.svc.Case.Delete(id, middleware.GetUserID(c)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ============ Family Handler ============

type FamilyHandler struct{ svc *service.Services }

func NewFamilyHandler(svc *service.Services) *FamilyHandler { return &FamilyHandler{svc: svc} }

func (h *FamilyHandler) Create(c *gin.Context) {
	var req struct {
		Name string `json:"name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	group, err := h.svc.Family.CreateGroup(req.Name, middleware.GetUserID(c))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": group.ID, "role": "admin"})
}

func (h *FamilyHandler) List(c *gin.Context) {
	groups, err := h.svc.Family.ListGroups(middleware.GetUserID(c))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, groups)
}

func (h *FamilyHandler) Get(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	group, err := h.svc.Family.GetGroup(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "group not found"})
		return
	}
	c.JSON(http.StatusOK, group)
}

func (h *FamilyHandler) Delete(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	if err := h.svc.Family.DeleteGroup(id, middleware.GetUserID(c)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *FamilyHandler) Invite(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	var req struct {
		Phone string `json:"phone"`
	}
	c.ShouldBindJSON(&req)
	// TODO: send invite notification via push
	c.JSON(http.StatusOK, gin.H{"group_id": id, "phone": req.Phone, "status": "invited"})
}

func (h *FamilyHandler) GenerateQRCode(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	invite, err := h.svc.Family.GenerateInviteCode(id, middleware.GetUserID(c))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"invite_code": invite.InviteCode,
		"expires_at":  invite.ExpiresAt,
		"qr_data":     "familyhealth://invite?code=" + invite.InviteCode,
	})
}

func (h *FamilyHandler) Join(c *gin.Context) {
	var req struct {
		InviteCode string `json:"invite_code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	group, err := h.svc.Family.JoinByCode(req.InviteCode, middleware.GetUserID(c))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"group": group, "role": "member"})
}

func (h *FamilyHandler) MemberReports(c *gin.Context) {
	groupID, _ := uuid.Parse(c.Param("id"))
	userID := middleware.GetUserID(c)

	// Verify admin
	group, err := h.svc.Family.GetGroup(groupID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "group not found"})
		return
	}
	if group.CreatorID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "only admin can view member reports"})
		return
	}

	type MemberData struct {
		UserID  uuid.UUID            `json:"user_id"`
		Reports []model.HealthReport `json:"reports"`
	}
	var result []MemberData
	for _, m := range group.Members {
		reports, _, _ := h.svc.Report.List(m.UserID, 1, 100)
		result = append(result, MemberData{UserID: m.UserID, Reports: reports})
	}
	c.JSON(http.StatusOK, gin.H{"members": result})
}

// ============ AI Handler ============

type AIHandler struct {
	svc *service.Services
	cfg *config.Config
}

func NewAIHandler(svc *service.Services, cfg *config.Config) *AIHandler {
	return &AIHandler{svc: svc, cfg: cfg}
}

// providerConfig maps provider name to (endpoint, apiKey)
func (h *AIHandler) providerConfig(provider string) (endpoint, apiKey string, ok bool) {
	switch provider {
	case "deepseek":
		return "https://api.deepseek.com/v1", h.cfg.DeepSeekAPIKey, h.cfg.DeepSeekAPIKey != ""
	case "glm":
		return "https://open.bigmodel.cn/api/paas/v4", h.cfg.GLMAPIKey, h.cfg.GLMAPIKey != ""
	case "kimi":
		return "https://api.moonshot.cn/v1", h.cfg.KimiAPIKey, h.cfg.KimiAPIKey != ""
	case "doubao":
		return "https://ark.cn-beijing.volces.com/api/v3", h.cfg.DoubaoAPIKey, h.cfg.DoubaoAPIKey != ""
	case "qwen":
		return "https://dashscope.aliyuncs.com/compatible-mode/v1", h.cfg.QwenAPIKey, h.cfg.QwenAPIKey != ""
	default:
		return "", "", false
	}
}

// Proxy streams AI chat via SSE — POST /api/v1/ai/proxy
func (h *AIHandler) Proxy(c *gin.Context) {
	var req struct {
		Provider string `json:"provider" binding:"required"`
		Model    string `json:"model" binding:"required"`
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages" binding:"required"`
		Stream bool `json:"stream"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	endpoint, apiKey, ok := h.providerConfig(req.Provider)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported or unconfigured provider: " + req.Provider})
		return
	}

	// Build upstream request body
	body, _ := json.Marshal(map[string]interface{}{
		"model":    req.Model,
		"messages": req.Messages,
		"stream":   req.Stream,
	})

	upstreamURL := endpoint + "/chat/completions"
	upReq, err := http.NewRequestWithContext(c.Request.Context(), "POST", upstreamURL, bytes.NewReader(body))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create upstream request"})
		return
	}
	upReq.Header.Set("Content-Type", "application/json")
	upReq.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := http.DefaultClient.Do(upReq)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "upstream request failed: " + err.Error()})
		return
	}
	defer resp.Body.Close()

	if !req.Stream {
		// Non-streaming: forward response as-is
		c.DataFromReader(resp.StatusCode, resp.ContentLength, resp.Header.Get("Content-Type"), resp.Body, nil)
		return
	}

	// Streaming: forward SSE
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Status(resp.StatusCode)

	flusher, _ := c.Writer.(http.Flusher)
	buf := make([]byte, 4096)
	for {
		n, readErr := resp.Body.Read(buf)
		if n > 0 {
			c.Writer.Write(buf[:n])
			if flusher != nil {
				flusher.Flush()
			}
		}
		if readErr != nil {
			break
		}
	}
}

func (h *AIHandler) Chat(c *gin.Context) {
	// Legacy endpoint — redirect to Proxy
	c.JSON(http.StatusOK, gin.H{"message": "Use POST /api/v1/ai/proxy instead"})
}

func (h *AIHandler) AnalyzeReport(c *gin.Context) {
	id, _ := uuid.Parse(c.Param("id"))
	report, err := h.svc.Report.Get(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "report not found"})
		return
	}
	_ = report
	c.JSON(http.StatusOK, gin.H{"analysis": "Use POST /api/v1/ai/proxy for analysis"})
}

func (h *AIHandler) ListConversations(c *gin.Context) {
	c.JSON(http.StatusOK, []model.ChatConversation{})
}

func (h *AIHandler) DeleteConversation(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
