// BATIX Core Monolith en Go organisé en blocs (Section 20.1 du Cahier des Charges)
// Blocs : comptes, vérification, catalogue, stock, offres, avantages, commandes,
// transport, preuve de livraison, paiement, litiges, notifications, calculs, devis, journal.
package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"sync"
	"time"
)

type PlatformSettings struct {
	CommissionPct     float64 `json:"commission_pct"`
	GeofenceRadiusM   float64 `json:"geofence_radius_m"`
	StockConfirmMin   int     `json:"stock_confirm_min"`
	PaymentWindowMin  int     `json:"payment_window_min"`
	ClaimWindowHours  int     `json:"claim_window_hours"`
	DisputeReplyHours int     `json:"dispute_reply_hours"`
	TvaPct            float64 `json:"tva_pct"`
}

type AuditEntry struct {
	Seq       int       `json:"seq"`
	Timestamp time.Time `json:"timestamp"`
	Actor     string    `json:"actor"`
	Action    string    `json:"action"`
	PrevHash  string    `json:"prev_hash"`
	Hash      string    `json:"hash"`
}

var (
	mu       sync.Mutex
	settings = PlatformSettings{
		CommissionPct:     3.0,
		GeofenceRadiusM:   150.0,
		StockConfirmMin:   15,
		PaymentWindowMin:  30,
		ClaimWindowHours:  24,
		DisputeReplyHours: 48,
		TvaPct:            19.25,
	}
	auditChain = []AuditEntry{}
	seenPhotos = map[string]string{} // photoSHA256 -> missionID (anti-reuse Section 9.3)
)

func appendAudit(actor, action string) AuditEntry {
	mu.Lock()
	defer mu.Unlock()
	prev := "0000000000000000000000000000000000000000000000000000000000000000"
	if len(auditChain) > 0 {
		prev = auditChain[len(auditChain)-1].Hash
	}
	ts := time.Now().UTC()
	payload := fmt.Sprintf("%s|%s|%s|%s", prev, actor, action, ts.Format(time.RFC3339Nano))
	sum := sha256.Sum256([]byte(payload))
	entry := AuditEntry{
		Seq:       len(auditChain) + 1,
		Timestamp: ts,
		Actor:     actor,
		Action:    action,
		PrevHash:  prev,
		Hash:      hex.EncodeToString(sum[:]),
	}
	auditChain = append(auditChain, entry)
	return entry
}

// Vérifie les 7 contrôles automatiques de la preuve de livraison (Section 9.3)
func verifyProofOfDeliveryHandler(w http.ResponseWriter, r *http.Request) {
	type ProofInput struct {
		MissionID      string   `json:"mission_id"`
		PhotosSHA256   []string `json:"photos_sha256"`
		DistancesM     []float64 `json:"distances_m"`
		SignatureValid bool     `json:"signature_valid"`
		OrderedQty     int      `json:"ordered_qty"`
		ReceivedQty    int      `json:"received_qty"`
		PhoneDriftMin  float64  `json:"phone_drift_min"`
	}
	var in ProofInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, `{"code":"BAD_JSON","message":"Format invalide"}`, http.StatusBadRequest)
		return
	}

	if len(in.PhotosSHA256) != 3 || len(in.DistancesM) != 3 {
		w.WriteHeader(http.StatusUnprocessableEntity)
		json.NewEncoder(w).Encode(map[string]any{"status": "REFUSED", "reason": "livraison incomplète : 3 photos dans l'ordre requises"})
		return
	}
	if !in.SignatureValid {
		w.WriteHeader(http.StatusUnprocessableEntity)
		json.NewEncoder(w).Encode(map[string]any{"status": "REFUSED", "reason": "signature du réceptionnaire manquante"})
		return
	}
	for i, d := range in.DistancesM {
		if d > settings.GeofenceRadiusM {
			json.NewEncoder(w).Encode(map[string]any{"status": "AGENT_REVIEW", "reason": fmt.Sprintf("Photo %d prise à %.1fm (> %.0fm)", i+1, d, settings.GeofenceRadiusM)})
			return
		}
	}
	for _, h := range in.PhotosSHA256 {
		if prevMission, exists := seenPhotos[h]; exists && prevMission != in.MissionID {
			json.NewEncoder(w).Encode(map[string]any{"status": "AGENT_REVIEW_FRAUD", "reason": "Photo déjà utilisée sur la mission " + prevMission})
			return
		}
		seenPhotos[h] = in.MissionID
	}
	if math.Abs(in.PhoneDriftMin) > 120 {
		json.NewEncoder(w).Encode(map[string]any{"status": "AGENT_REVIEW", "reason": "Heure du téléphone décalée de plusieurs heures"})
		return
	}
	if in.ReceivedQty < in.OrderedQty {
		appendAudit("SYSTEM_POD", fmt.Sprintf("PARTIAL_DELIVERY %s : %d/%d reçus", in.MissionID, in.ReceivedQty, in.OrderedQty))
		json.NewEncoder(w).Encode(map[string]any{"status": "PARTIAL_DISPUTE", "paid_qty": in.ReceivedQty, "disputed_qty": in.OrderedQty - in.ReceivedQty})
		return
	}

	appendAudit("SYSTEM_POD", "AUTO_PAYOUT_RELEASED "+in.MissionID)
	json.NewEncoder(w).Encode(map[string]any{"status": "VALIDATED_AUTO_PAID", "mission_id": in.MissionID})
}

// Vérifie la signature HMAC du partenaire de paiement Mobile Money (Section 10.4)
func VerifyPartnerWebhookHMAC(payload []byte, signatureHex string, secret string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expected := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(signatureHex))
}

func main() {
	appendAudit("SYSTEM_BOOT", "Démarrage du cœur BATIX v3.1 (Yaoundé, Cameroun)")
	http.HandleFunc("/api/v1/pod/verify", verifyProofOfDeliveryHandler)
	http.HandleFunc("/api/v1/health", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"status": "OK", "version": "3.1.0", "city": "Yaoundé", "currency": "FCFA"})
	})
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("BATIX Core API listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
