const assert = require('assert');
const { shouldCallNow, shouldCallLater, getCallAction, formatLeadSummary } = require('../integrations/enrichment/simple-lead-filter');

describe('SimpleLeadFilter', () => {
  describe('shouldCallNow', () => {
    it('should return true for good size, nearby, owner', () => {
      const lead = {
        roof_area_sqm: 45,
        distance_km: 30,
        is_owner: true,
        missed_calls: 0
      };
      assert.strictEqual(shouldCallNow(lead), true);
    });

    it('should return true for urgent missed calls', () => {
      const lead = {
        roof_area_sqm: 20,
        distance_km: 80,
        is_owner: false,
        missed_calls: 2
      };
      assert.strictEqual(shouldCallNow(lead), true);
    });

    it('should return false for poor quality lead', () => {
      const lead = {
        roof_area_sqm: 30,
        distance_km: 60,
        is_owner: false,
        missed_calls: 0
      };
      assert.strictEqual(shouldCallNow(lead), false);
    });

    it('should handle missing fields gracefully', () => {
      const lead = {};
      assert.strictEqual(shouldCallNow(lead), false);
    });
  });

  describe('shouldCallLater', () => {
    it('should return true for decent size, reasonable distance, interested', () => {
      const lead = {
        roof_area_sqm: 25,
        distance_km: 80,
        interested: true
      };
      assert.strictEqual(shouldCallLater(lead), true);
    });

    it('should return false for small roof', () => {
      const lead = {
        roof_area_sqm: 15,
        distance_km: 50,
        interested: true
      };
      assert.strictEqual(shouldCallLater(lead), false);
    });

    it('should return false for far distance', () => {
      const lead = {
        roof_area_sqm: 25,
        distance_km: 150,
        interested: true
      };
      assert.strictEqual(shouldCallLater(lead), false);
    });

    it('should return false for not interested', () => {
      const lead = {
        roof_area_sqm: 25,
        distance_km: 50,
        interested: false
      };
      assert.strictEqual(shouldCallLater(lead), false);
    });
  });

  describe('getCallAction', () => {
    it('should return call_now for urgent lead', () => {
      const lead = {
        roof_area_sqm: 45,
        distance_km: 30,
        is_owner: true
      };
      assert.strictEqual(getCallAction(lead), 'call_now');
    });

    it('should return call_later for decent lead', () => {
      const lead = {
        roof_area_sqm: 25,
        distance_km: 80,
        interested: true
      };
      assert.strictEqual(getCallAction(lead), 'call_later');
    });

    it('should return skip for poor lead', () => {
      const lead = {
        roof_area_sqm: 15,
        distance_km: 100,
        is_owner: false,
        interested: false
      };
      assert.strictEqual(getCallAction(lead), 'skip');
    });
  });

  describe('formatLeadSummary', () => {
    it('should format lead summary correctly', () => {
      const lead = {
        name: 'Max Mustermann',
        roof_area_sqm: 45,
        distance_km: 12.5,
        is_owner: true
      };
      const summary = formatLeadSummary(lead);
      assert.strictEqual(summary, 'Max Mustermann | 45m² | 13km | Eigentümer');
    });

    it('should handle missing name', () => {
      const lead = {
        roof_area_sqm: 40,
        distance_km: 20,
        is_owner: false
      };
      const summary = formatLeadSummary(lead);
      assert.strictEqual(summary, 'Unbekannt | 40m² | 20km | Mieter');
    });

    it('should handle missing distance', () => {
      const lead = {
        name: 'Test',
        roof_area_sqm: 40,
        is_owner: true
      };
      const summary = formatLeadSummary(lead);
      assert.strictEqual(summary, 'Test | 40m² | ?km | Eigentümer');
    });
  });
});
