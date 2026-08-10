package main

import (
  "os"
  "path/filepath"
  "strings"
  "testing"
)

func TestWriteConfUpdates(t *testing.T) {
  dir := t.TempDir()
  p := filepath.Join(dir, "dogecoin.conf")
  src := "# comment\nserver=1\nrpcuser=gpenode\nrpcpassword=OLD\nprune=5500\n"
  if err := os.WriteFile(p, []byte(src), 0600); err != nil { t.Fatal(err) }
  if err := writeConfUpdates(p, map[string]string{"rpcpassword": "NEW_SECRET_123", "dbcache": "2048"}); err != nil {
    t.Fatal(err)
  }
  b, _ := os.ReadFile(p)
  s := string(b)
  if !strings.Contains(s, "rpcpassword=NEW_SECRET_123") { t.Fatalf("password not updated: %s", s) }
  if !strings.Contains(s, "dbcache=2048") { t.Fatalf("dbcache not appended: %s", s) }
  if !strings.Contains(s, "# comment") { t.Fatal("comment lost") }
  // backup exists
  ents, _ := os.ReadDir(dir)
  bak := false
  for _, e := range ents {
    if strings.Contains(e.Name(), ".bak.") { bak = true }
  }
  if !bak { t.Fatal("no backup") }
}
