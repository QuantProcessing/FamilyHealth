package service

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/familyhealth/server/internal/config"
	"github.com/familyhealth/server/internal/model"
	"github.com/familyhealth/server/internal/repository"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Services struct {
	Auth   *AuthService
	Report *ReportService
	Case   *CaseService
	Family *FamilyService
	AI     *AIService
}

// ============ Auth Service ============

type AuthService struct {
	repos     *repository.Repositories
	jwtSecret string
}

func NewAuthService(repos *repository.Repositories, cfg *config.Config) *AuthService {
	return &AuthService{repos: repos, jwtSecret: cfg.JWTSecret}
}

func (s *AuthService) LoginOrRegister(phone, name string) (*model.User, string, bool, error) {
	user, err := s.repos.User.FindByPhone(phone)
	isNew := false
	if err != nil {
		// Create new user
		user = &model.User{Phone: phone, Name: name}
		if err := s.repos.User.Create(user); err != nil {
			return nil, "", false, err
		}
		isNew = true
	}

	token, err := s.generateToken(user.ID)
	if err != nil {
		return nil, "", false, err
	}
	return user, token, isNew, nil
}

func (s *AuthService) generateToken(userID uuid.UUID) (string, error) {
	claims := jwt.MapClaims{
		"sub": userID.String(),
		"exp": time.Now().Add(24 * time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

func (s *AuthService) GetUser(id uuid.UUID) (*model.User, error) {
	return s.repos.User.FindByID(id)
}

func (s *AuthService) UpdateUser(user *model.User) error {
	return s.repos.User.Update(user)
}

// ============ Report Service ============

type ReportService struct {
	repos *repository.Repositories
}

func NewReportService(repos *repository.Repositories) *ReportService {
	return &ReportService{repos: repos}
}

func (s *ReportService) Create(report *model.HealthReport) error {
	return s.repos.Report.Create(report)
}

func (s *ReportService) List(userID uuid.UUID, page, size int) ([]model.HealthReport, int64, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 {
		size = 20
	}
	return s.repos.Report.FindByUserID(userID, page, size)
}

func (s *ReportService) Get(id uuid.UUID) (*model.HealthReport, error) {
	return s.repos.Report.FindByID(id)
}

func (s *ReportService) Delete(id uuid.UUID, userID uuid.UUID) error {
	report, err := s.repos.Report.FindByID(id)
	if err != nil {
		return err
	}
	if report.UserID != userID && report.UploaderID != userID {
		return errors.New("permission denied")
	}
	return s.repos.Report.Delete(id)
}

// ============ Case Service ============

type CaseService struct {
	repos *repository.Repositories
}

func NewCaseService(repos *repository.Repositories) *CaseService {
	return &CaseService{repos: repos}
}

func (s *CaseService) Create(c *model.MedicalCase) error {
	return s.repos.MedicalCase.Create(c)
}

func (s *CaseService) List(userID uuid.UUID, page, size int) ([]model.MedicalCase, int64, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 {
		size = 20
	}
	return s.repos.MedicalCase.FindByUserID(userID, page, size)
}

func (s *CaseService) Get(id uuid.UUID) (*model.MedicalCase, error) {
	return s.repos.MedicalCase.FindByID(id)
}

func (s *CaseService) Delete(id uuid.UUID, userID uuid.UUID) error {
	c, err := s.repos.MedicalCase.FindByID(id)
	if err != nil {
		return err
	}
	if c.UserID != userID && c.UploaderID != userID {
		return errors.New("permission denied")
	}
	return s.repos.MedicalCase.Delete(id)
}

// ============ Family Service ============

type FamilyService struct {
	repos *repository.Repositories
}

func NewFamilyService(repos *repository.Repositories) *FamilyService {
	return &FamilyService{repos: repos}
}

const MaxGroupsPerUser = 2

func (s *FamilyService) CreateGroup(name string, creatorID uuid.UUID) (*model.FamilyGroup, error) {
	count, _ := s.repos.Family.CountUserGroups(creatorID)
	if count >= MaxGroupsPerUser {
		return nil, errors.New("最多只能加入 2 个家庭组")
	}

	group := &model.FamilyGroup{Name: name, CreatorID: creatorID}
	if err := s.repos.Family.CreateGroup(group); err != nil {
		return nil, err
	}

	member := &model.FamilyMember{
		GroupID:  group.ID,
		UserID:   creatorID,
		Role:     "admin",
		JoinedAt: time.Now(),
	}
	if err := s.repos.Family.AddMember(member); err != nil {
		return nil, err
	}
	return group, nil
}

func (s *FamilyService) ListGroups(userID uuid.UUID) ([]model.FamilyGroup, error) {
	return s.repos.Family.FindGroupsByUserID(userID)
}

func (s *FamilyService) GetGroup(id uuid.UUID) (*model.FamilyGroup, error) {
	return s.repos.Family.FindGroupByID(id)
}

func (s *FamilyService) DeleteGroup(id uuid.UUID, userID uuid.UUID) error {
	group, err := s.repos.Family.FindGroupByID(id)
	if err != nil {
		return err
	}
	if group.CreatorID != userID {
		return errors.New("only admin can delete group")
	}
	return s.repos.Family.DeleteGroup(id)
}

func (s *FamilyService) GenerateInviteCode(groupID, inviterID uuid.UUID) (*model.FamilyInvite, error) {
	isAdmin, _ := s.repos.Family.IsAdmin(inviterID, groupID)
	if !isAdmin {
		return nil, errors.New("only admin can invite")
	}

	code := make([]byte, 16)
	rand.Read(code)
	invite := &model.FamilyInvite{
		GroupID:    groupID,
		InviteCode: hex.EncodeToString(code),
		InviterID:  inviterID,
		Status:     "pending",
		ExpiresAt:  time.Now().Add(24 * time.Hour),
	}
	if err := s.repos.Family.CreateInvite(invite); err != nil {
		return nil, err
	}
	return invite, nil
}

func (s *FamilyService) JoinByCode(code string, userID uuid.UUID) (*model.FamilyGroup, error) {
	count, _ := s.repos.Family.CountUserGroups(userID)
	if count >= MaxGroupsPerUser {
		return nil, errors.New("最多只能加入 2 个家庭组")
	}

	invite, err := s.repos.Family.FindInviteByCode(code)
	if err != nil {
		return nil, errors.New("邀请码无效")
	}
	if invite.ExpiresAt.Before(time.Now()) {
		s.repos.Family.UpdateInviteStatus(invite.ID, "expired")
		return nil, errors.New("邀请码已过期")
	}

	member := &model.FamilyMember{
		GroupID:   invite.GroupID,
		UserID:    userID,
		Role:      "member",
		InvitedBy: &invite.InviterID,
		JoinedAt:  time.Now(),
	}
	if err := s.repos.Family.AddMember(member); err != nil {
		return nil, err
	}

	s.repos.Family.UpdateInviteStatus(invite.ID, "accepted")
	return s.repos.Family.FindGroupByID(invite.GroupID)
}

// ============ AI Service ============

type AIService struct {
	cfg *config.Config
}

func NewAIService(cfg *config.Config) *AIService {
	return &AIService{cfg: cfg}
}
