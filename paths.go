package main

import (
	"errors"
	"os"
	"path"
)

func getStoragePath() (string, error) {
	p, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}

	fp := path.Join(p, "bradcypert")
	return fp, nil
}

func getBookmarkFilePath() (string, error) {
	s, err := getStoragePath()
	if err != nil {
		return "", err
	}

	p := path.Join(s, "bookmarks.csv")
	return p, nil
}

func DeleteBookmarkFile() error {
	p, err := getBookmarkFilePath()
	if err != nil {
		return err
	}
	return os.Remove(p)
}

func getBookmarkFile(fileMode int) (*os.File, error) {
	p, err := getBookmarkFilePath()
	if err != nil {
		return nil, err
	}

	sp, err := getStoragePath()
	if err != nil {
		return nil, err
	}

	os.MkdirAll(sp, os.ModePerm)

	if _, err := os.Stat(p); errors.Is(err, os.ErrNotExist) {
		file, err := os.Create(p)
		if err != nil {
			return nil, err
		}

		return file, nil
	}

	// if it exists, just open it
	file, err := os.OpenFile(p, fileMode, os.ModeAppend)
	if err != nil {
		return nil, err
	}

	return file, nil
}
