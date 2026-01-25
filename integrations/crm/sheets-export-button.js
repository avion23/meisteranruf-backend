const { GoogleSpreadsheet } = require('google-spreadsheet');
const { Client } = require('pg');

class SheetsExportButton {
  constructor(config) {
    this.sheetId = config.sheetId;
    this.credentials = config.googleCredentials;
    this.pgConfig = config.postgres;
  }

  async exportToSheets() {
    const pg = new Client(this.pgConfig);
    await pg.connect();

    try {
      const sheet = new GoogleSpreadsheet(this.sheetId);
      await sheet.useServiceAccountAuth(this.credentials);
      await sheet.loadInfo();

      const leads = await this.fetchLeads(pg);
      const sheetTitle = `Leads_Export_${new Date().toISOString().split('T')[0]}`;

      let worksheet = sheet.sheetsByTitle[sheetTitle];
      if (!worksheet) {
        worksheet = await sheet.addWorksheet({ title: sheetTitle });
      }

      const headers = this.getHeaders();
      await worksheet.setHeaderRow(headers);

      const rows = leads.map(lead => this.formatRow(lead));
      await worksheet.addRows(rows);

      await this.applyStatusColors(worksheet, leads);

      return {
        success: true,
        sheetUrl: sheet.url,
        worksheetTitle: sheetTitle,
        rowsExported: leads.length
      };
    } finally {
      await pg.end();
    }
  }

  async fetchLeads(pg) {
    const query = `
      SELECT 
        id,
        name,
        phone,
        email,
        address_raw,
        address_city,
        address_postal_code,
        status,
        priority,
        roof_area_sqm,
        estimated_kwp,
        appointment_today,
        appointment_time,
        appointment_confirmed,
        distance_km,
        is_owner,
        missed_calls,
        interested,
        notes,
        created_at,
        updated_at
      FROM leads
      ORDER BY created_at DESC
    `;

    const result = await pg.query(query);
    return result.rows;
  }

  getHeaders() {
    return [
      'Name',
      'Telefon',
      'Email',
      'Adresse',
      'Stadt',
      'PLZ',
      'Status',
      'Priorität',
      'Dachfläche (m²)',
      'Geschätzte kWp',
      'Termin heute',
      'Uhrzeit',
      'Termin bestätigt',
      'Entfernung (km)',
      'Eigentümer',
      'Verpasste Anrufe',
      'Interessiert',
      'Notizen',
      'Erstellt am',
      'Aktualisiert am'
    ];
  }

  formatRow(lead) {
    return {
      name: lead.name || '',
      phone: lead.phone || '',
      email: lead.email || '',
      address: lead.address_raw || '',
      city: lead.address_city || '',
      postalCode: lead.address_postal_code || '',
      status: lead.status || 'new',
      priority: lead.priority === 2 ? 'Hoch' : lead.priority === 1 ? 'Mittel' : 'Normal',
      roofArea: lead.roof_area_sqm || 0,
      estimatedKwp: lead.estimated_kwp || 0,
      appointmentToday: lead.appointment_today ? 'Ja' : 'Nein',
      appointmentTime: lead.appointment_time || '',
      appointmentConfirmed: lead.appointment_confirmed ? 'Ja' : 'Nein',
      distance: lead.distance_km || 0,
      isOwner: lead.is_owner ? 'Ja' : 'Nein',
      missedCalls: lead.missed_calls || 0,
      interested: lead.interested ? 'Ja' : 'Nein',
      notes: lead.notes || '',
      createdAt: lead.created_at ? new Date(lead.created_at).toLocaleString('de-DE') : '',
      updatedAt: lead.updated_at ? new Date(lead.updated_at).toLocaleString('de-DE') : ''
    };
  }

  async applyStatusColors(worksheet, leads) {
    const statusColors = {
      'new': { red: 1, green: 0.9, blue: 0.8 },
      'qualified': { red: 0.8, green: 1, blue: 0.8 },
      'contacted': { red: 0.8, green: 0.9, blue: 1 },
      'meeting': { red: 1, green: 1, blue: 0.8 },
      'offer': { red: 1, green: 0.9, blue: 0.6 },
      'won': { red: 0.8, green: 1, blue: 0.8 },
      'lost': { red: 1, green: 0.8, blue: 0.8 }
    };

    const rows = await worksheet.getRows();
    
    for (let i = 0; i < Math.min(rows.length, leads.length); i++) {
      const status = leads[i].status;
      const color = statusColors[status];
      
      if (color) {
        await rows[i].setBackgroundColor(color);
      }
    }
  }

  async exportTodayAppointments() {
    const pg = new Client(this.pgConfig);
    await pg.connect();

    try {
      const query = `
        SELECT 
          id,
          name,
          phone,
          address_raw,
          address_city,
          appointment_time,
          appointment_confirmed,
          latitude,
          longitude
        FROM leads
        WHERE appointment_today = TRUE
        ORDER BY appointment_time
      `;

      const result = await pg.query(query);
      
      const sheet = new GoogleSpreadsheet(this.sheetId);
      await sheet.useServiceAccountAuth(this.credentials);
      await sheet.loadInfo();

      const sheetTitle = `Termine_${new Date().toISOString().split('T')[0]}`;
      let worksheet = sheet.sheetsByTitle[sheetTitle];
      if (!worksheet) {
        worksheet = await sheet.addWorksheet({ title: sheetTitle });
      }

      await worksheet.setHeaderRow(['Name', 'Telefon', 'Adresse', 'Stadt', 'Uhrzeit', 'Bestätigt', 'Breitengrad', 'Längengrad']);

      const rows = result.rows.map(lead => ({
        name: lead.name || '',
        phone: lead.phone || '',
        address: lead.address_raw || '',
        city: lead.address_city || '',
        time: lead.appointment_time || '',
        confirmed: lead.appointment_confirmed ? 'Ja' : 'Nein',
        lat: lead.latitude || '',
        lon: lead.longitude || ''
      }));

      await worksheet.addRows(rows);

      return {
        success: true,
        sheetUrl: sheet.url,
        appointments: result.rows.length
      };
    } finally {
      await pg.end();
    }
  }
}

module.exports = SheetsExportButton;
