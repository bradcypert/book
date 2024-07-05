package main

import (
	"strings"
	"testing"
)

func TestSearch(t *testing.T) {
	matches, err := SearchBookmarks(strings.NewReader("goog,https://www.google.com,search,common\ngh,https://www.github.com,code,projects"), "og")
	if err != nil {
		t.Fatalf("received error when searching bookmarks, %v", err)
	}

	if len(matches) != 1 {
		t.Fatal("received too many matches during search")
	}

	if matches[0].Value != "goog" {
		t.Fatal("did not find the google bookmark")
	}

	if matches[0].Path != "https://www.google.com" {
		t.Fatal("did not find the google.com path")
	}

	if matches[0].Tags[0] != "search" {
		t.Fatal("did not find the search tag")
	}

	if matches[0].Tags[1] != "common" {
		t.Fatal("did not find the common tag")
	}
}
