package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User model
type User struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Phone     string     `gorm:"uniqueIndex;size:20;not null" json:"phone"`
	Name      string     `gorm:"size:100;not null" json:"name"`
	Gender    string     `gorm:"size:10" json:"gender"`
	BirthDate *time.Time `json:"birth_date,omitempty"`
	Height    *float64   `json:"height,omitempty"`
	Weight    *float64   `json:"weight,omitempty"`
	AvatarURL string     `json:"avatar_url,omitempty"`
	PushToken string     `json:"-"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}

// HealthReport model
type HealthReport struct {
	ID           uuid.UUID    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID       uuid.UUID    `gorm:"type:uuid;not null;index" json:"user_id"`
	UploaderID   uuid.UUID    `gorm:"type:uuid;not null" json:"uploader_id"`
	Title        string       `gorm:"size:200;not null" json:"title"`
	HospitalName *string      `gorm:"size:200" json:"hospital_name,omitempty"`
	ReportDate   time.Time    `gorm:"not null" json:"report_date"`
	ReportType   string       `gorm:"size:20" json:"report_type"`
	Notes        *string      `json:"notes,omitempty"`
	AIAnalysis   *string      `json:"ai_analysis,omitempty"`
	Files        []ReportFile `gorm:"foreignKey:ReportID;constraint:OnDelete:CASCADE" json:"files"`
	CreatedAt    time.Time    `json:"created_at"`
	UpdatedAt    time.Time    `json:"updated_at"`
}

func (r *HealthReport) BeforeCreate(tx *gorm.DB) error {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	return nil
}

// ReportFile model
type ReportFile struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReportID   uuid.UUID `gorm:"type:uuid;not null" json:"report_id"`
	FileType   string    `gorm:"size:10" json:"file_type"`
	StorageKey string    `gorm:"not null" json:"storage_key"`
	FileName   string    `gorm:"size:500;not null" json:"file_name"`
	FileSize   int64     `json:"file_size"`
	OCRText    *string   `json:"ocr_text,omitempty"`
}

// MedicalCase model
type MedicalCase struct {
	ID           uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID       uuid.UUID        `gorm:"type:uuid;not null;index" json:"user_id"`
	UploaderID   uuid.UUID        `gorm:"type:uuid;not null" json:"uploader_id"`
	Title        string           `gorm:"size:200;not null" json:"title"`
	HospitalName *string          `gorm:"size:200" json:"hospital_name,omitempty"`
	DoctorName   *string          `gorm:"size:100" json:"doctor_name,omitempty"`
	VisitDate    time.Time        `gorm:"not null" json:"visit_date"`
	Diagnosis    *string          `json:"diagnosis,omitempty"`
	Symptoms     StringArray      `gorm:"type:text[]" json:"symptoms"`
	Notes        *string          `json:"notes,omitempty"`
	Medications  []Medication     `gorm:"foreignKey:CaseID;constraint:OnDelete:CASCADE" json:"medications"`
	Attachments  []CaseAttachment `gorm:"foreignKey:CaseID;constraint:OnDelete:CASCADE" json:"attachments"`
	CreatedAt    time.Time        `json:"created_at"`
	UpdatedAt    time.Time        `json:"updated_at"`
}

func (c *MedicalCase) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

// Medication model
type Medication struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	CaseID    uuid.UUID  `gorm:"type:uuid;not null" json:"case_id"`
	Name      string     `gorm:"size:200;not null" json:"name"`
	Dosage    *string    `gorm:"size:100" json:"dosage,omitempty"`
	Frequency *string    `gorm:"size:100" json:"frequency,omitempty"`
	StartDate *time.Time `json:"start_date,omitempty"`
	EndDate   *time.Time `json:"end_date,omitempty"`
}

// CaseAttachment model
type CaseAttachment struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	CaseID     uuid.UUID `gorm:"type:uuid;not null" json:"case_id"`
	FileType   string    `gorm:"size:10" json:"file_type"`
	StorageKey string    `gorm:"not null" json:"storage_key"`
	FileName   string    `gorm:"size:500;not null" json:"file_name"`
}

// FamilyGroup model
type FamilyGroup struct {
	ID        uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Name      string         `gorm:"size:100;not null" json:"name"`
	CreatorID uuid.UUID      `gorm:"type:uuid;not null" json:"creator_id"`
	Members   []FamilyMember `gorm:"foreignKey:GroupID;constraint:OnDelete:CASCADE" json:"members"`
	CreatedAt time.Time      `json:"created_at"`
}

func (g *FamilyGroup) BeforeCreate(tx *gorm.DB) error {
	if g.ID == uuid.Nil {
		g.ID = uuid.New()
	}
	return nil
}

// FamilyMember model
type FamilyMember struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	GroupID   uuid.UUID  `gorm:"type:uuid;not null;uniqueIndex:idx_group_user" json:"group_id"`
	UserID    uuid.UUID  `gorm:"type:uuid;not null;uniqueIndex:idx_group_user" json:"user_id"`
	Role      string     `gorm:"size:10;not null" json:"role"`
	InvitedBy *uuid.UUID `gorm:"type:uuid" json:"invited_by,omitempty"`
	JoinedAt  time.Time  `json:"joined_at"`
}

// FamilyInvite model
type FamilyInvite struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	GroupID    uuid.UUID `gorm:"type:uuid;not null" json:"group_id"`
	InviteCode string    `gorm:"uniqueIndex;size:32;not null" json:"invite_code"`
	InviterID  uuid.UUID `gorm:"type:uuid;not null" json:"inviter_id"`
	Phone      *string   `gorm:"size:20" json:"phone,omitempty"`
	Status     string    `gorm:"size:10;default:pending" json:"status"`
	ExpiresAt  time.Time `json:"expires_at"`
	CreatedAt  time.Time `json:"created_at"`
}

// ChatConversation model
type ChatConversation struct {
	ID        uuid.UUID     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID    uuid.UUID     `gorm:"type:uuid;not null;index" json:"user_id"`
	Title     *string       `gorm:"size:200" json:"title,omitempty"`
	ModelName *string       `gorm:"size:100" json:"model_name,omitempty"`
	Messages  []ChatMessage `gorm:"foreignKey:ConversationID;constraint:OnDelete:CASCADE" json:"messages"`
	CreatedAt time.Time     `json:"created_at"`
	UpdatedAt time.Time     `json:"updated_at"`
}

func (c *ChatConversation) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

// ChatMessage model
type ChatMessage struct {
	ID             uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ConversationID uuid.UUID `gorm:"type:uuid;not null;index" json:"conversation_id"`
	Role           string    `gorm:"size:10;not null" json:"role"`
	Content        string    `gorm:"not null" json:"content"`
	CreatedAt      time.Time `json:"created_at"`
}
