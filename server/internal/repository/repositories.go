package repository

import (
	"github.com/familyhealth/server/internal/model"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Repositories struct {
	User        *UserRepo
	Report      *ReportRepo
	MedicalCase *CaseRepo
	Family      *FamilyRepo
	Chat        *ChatRepo
}

// ============ User Repository ============

type UserRepo struct{ db *gorm.DB }

func NewUserRepo(db *gorm.DB) *UserRepo { return &UserRepo{db: db} }

func (r *UserRepo) Create(user *model.User) error {
	return r.db.Create(user).Error
}

func (r *UserRepo) FindByPhone(phone string) (*model.User, error) {
	var user model.User
	err := r.db.Where("phone = ?", phone).First(&user).Error
	return &user, err
}

func (r *UserRepo) FindByID(id uuid.UUID) (*model.User, error) {
	var user model.User
	err := r.db.First(&user, "id = ?", id).Error
	return &user, err
}

func (r *UserRepo) Update(user *model.User) error {
	return r.db.Save(user).Error
}

// ============ Report Repository ============

type ReportRepo struct{ db *gorm.DB }

func NewReportRepo(db *gorm.DB) *ReportRepo { return &ReportRepo{db: db} }

func (r *ReportRepo) Create(report *model.HealthReport) error {
	return r.db.Create(report).Error
}

func (r *ReportRepo) FindByUserID(userID uuid.UUID, page, size int) ([]model.HealthReport, int64, error) {
	var reports []model.HealthReport
	var total int64
	q := r.db.Where("user_id = ?", userID)
	q.Model(&model.HealthReport{}).Count(&total)
	err := q.Preload("Files").
		Order("report_date DESC").
		Offset((page - 1) * size).Limit(size).
		Find(&reports).Error
	return reports, total, err
}

func (r *ReportRepo) FindByID(id uuid.UUID) (*model.HealthReport, error) {
	var report model.HealthReport
	err := r.db.Preload("Files").First(&report, "id = ?", id).Error
	return &report, err
}

func (r *ReportRepo) Delete(id uuid.UUID) error {
	return r.db.Delete(&model.HealthReport{}, "id = ?", id).Error
}

func (r *ReportRepo) UpdateAnalysis(id uuid.UUID, analysis string) error {
	return r.db.Model(&model.HealthReport{}).Where("id = ?", id).Update("ai_analysis", analysis).Error
}

// ============ Case Repository ============

type CaseRepo struct{ db *gorm.DB }

func NewCaseRepo(db *gorm.DB) *CaseRepo { return &CaseRepo{db: db} }

func (r *CaseRepo) Create(c *model.MedicalCase) error {
	return r.db.Create(c).Error
}

func (r *CaseRepo) FindByUserID(userID uuid.UUID, page, size int) ([]model.MedicalCase, int64, error) {
	var cases []model.MedicalCase
	var total int64
	q := r.db.Where("user_id = ?", userID)
	q.Model(&model.MedicalCase{}).Count(&total)
	err := q.Preload("Medications").Preload("Attachments").
		Order("visit_date DESC").
		Offset((page - 1) * size).Limit(size).
		Find(&cases).Error
	return cases, total, err
}

func (r *CaseRepo) FindByID(id uuid.UUID) (*model.MedicalCase, error) {
	var c model.MedicalCase
	err := r.db.Preload("Medications").Preload("Attachments").First(&c, "id = ?", id).Error
	return &c, err
}

func (r *CaseRepo) Delete(id uuid.UUID) error {
	return r.db.Delete(&model.MedicalCase{}, "id = ?", id).Error
}

// ============ Family Repository ============

type FamilyRepo struct{ db *gorm.DB }

func NewFamilyRepo(db *gorm.DB) *FamilyRepo { return &FamilyRepo{db: db} }

func (r *FamilyRepo) CreateGroup(g *model.FamilyGroup) error {
	return r.db.Create(g).Error
}

func (r *FamilyRepo) FindGroupsByUserID(userID uuid.UUID) ([]model.FamilyGroup, error) {
	var groups []model.FamilyGroup
	err := r.db.Joins("JOIN family_members ON family_members.group_id = family_groups.id").
		Where("family_members.user_id = ?", userID).
		Preload("Members").
		Find(&groups).Error
	return groups, err
}

func (r *FamilyRepo) FindGroupByID(id uuid.UUID) (*model.FamilyGroup, error) {
	var g model.FamilyGroup
	err := r.db.Preload("Members").First(&g, "id = ?", id).Error
	return &g, err
}

func (r *FamilyRepo) DeleteGroup(id uuid.UUID) error {
	return r.db.Delete(&model.FamilyGroup{}, "id = ?", id).Error
}

func (r *FamilyRepo) CountUserGroups(userID uuid.UUID) (int64, error) {
	var count int64
	err := r.db.Model(&model.FamilyMember{}).Where("user_id = ?", userID).Count(&count).Error
	return count, err
}

func (r *FamilyRepo) AddMember(m *model.FamilyMember) error {
	return r.db.Create(m).Error
}

func (r *FamilyRepo) RemoveMember(groupID, userID uuid.UUID) error {
	return r.db.Where("group_id = ? AND user_id = ?", groupID, userID).Delete(&model.FamilyMember{}).Error
}

func (r *FamilyRepo) IsAdmin(userID, groupID uuid.UUID) (bool, error) {
	var count int64
	err := r.db.Model(&model.FamilyMember{}).
		Where("user_id = ? AND group_id = ? AND role = ?", userID, groupID, "admin").
		Count(&count).Error
	return count > 0, err
}

func (r *FamilyRepo) CreateInvite(inv *model.FamilyInvite) error {
	return r.db.Create(inv).Error
}

func (r *FamilyRepo) FindInviteByCode(code string) (*model.FamilyInvite, error) {
	var inv model.FamilyInvite
	err := r.db.Where("invite_code = ? AND status = ?", code, "pending").First(&inv).Error
	return &inv, err
}

func (r *FamilyRepo) UpdateInviteStatus(id uuid.UUID, status string) error {
	return r.db.Model(&model.FamilyInvite{}).Where("id = ?", id).Update("status", status).Error
}

// ============ Chat Repository ============

type ChatRepo struct{ db *gorm.DB }

func NewChatRepo(db *gorm.DB) *ChatRepo { return &ChatRepo{db: db} }

func (r *ChatRepo) CreateConversation(c *model.ChatConversation) error {
	return r.db.Create(c).Error
}

func (r *ChatRepo) FindConversationsByUserID(userID uuid.UUID) ([]model.ChatConversation, error) {
	var convs []model.ChatConversation
	err := r.db.Where("user_id = ?", userID).
		Preload("Messages", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
		Order("updated_at DESC").
		Find(&convs).Error
	return convs, err
}

func (r *ChatRepo) AddMessage(msg *model.ChatMessage) error {
	return r.db.Create(msg).Error
}

func (r *ChatRepo) DeleteConversation(id uuid.UUID) error {
	return r.db.Delete(&model.ChatConversation{}, "id = ?", id).Error
}

func (r *ChatRepo) UpdateConversationTimestamp(id uuid.UUID) error {
	return r.db.Model(&model.ChatConversation{}).Where("id = ?", id).Update("updated_at", gorm.Expr("NOW()")).Error
}
