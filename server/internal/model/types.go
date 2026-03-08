package model

import (
	"database/sql/driver"
	"strings"
)

// StringArray implements driver.Valuer and sql.Scanner for PostgreSQL text[] type
type StringArray []string

func (a StringArray) Value() (driver.Value, error) {
	if len(a) == 0 {
		return "{}", nil
	}
	return "{" + strings.Join(a, ",") + "}", nil
}

func (a *StringArray) Scan(src interface{}) error {
	if src == nil {
		*a = []string{}
		return nil
	}
	s := string(src.([]byte))
	s = strings.TrimPrefix(s, "{")
	s = strings.TrimSuffix(s, "}")
	if s == "" {
		*a = []string{}
		return nil
	}
	*a = strings.Split(s, ",")
	return nil
}
