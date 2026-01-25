const { Client } = require('pg');

class SocialProofEnricher {
  constructor(config) {
    this.pgConfig = {
      host: config.postgresHost,
      port: config.postgresPort,
      database: config.postgresDatabase,
      user: config.postgresUser,
      password: config.postgresPassword,
    };
    this.client = new Client(this.pgConfig);
  }

  async connect() {
    await this.client.connect();
  }

  async disconnect() {
    await this.client.end();
  }

  getPLZRegion(plz) {
    return plz.substring(0, 2);
  }

  async findRecentProjectsInPLZ(plz, limit = 3) {
    const plzRegion = this.getPLZRegion(plz);
    
    const query = `
      SELECT 
        id,
        customer_name,
        plz,
        city,
        installation_date,
        system_size_kw,
        photo_url,
        status
      FROM leads
      WHERE 
        plz LIKE $1 || '%' 
        AND status IN ('completed', 'installation_complete', 'paid')
        AND photo_url IS NOT NULL
      ORDER BY installation_date DESC
      LIMIT $2
    `;

    const result = await this.client.query(query, [plzRegion, limit]);
    return result.rows;
  }

  async countProjectsInPLZ(plz) {
    const plzRegion = this.getPLZRegion(plz);
    
    const query = `
      SELECT COUNT(*) as total
      FROM leads
      WHERE 
        plz LIKE $1 || '%' 
        AND status IN ('completed', 'installation_complete', 'paid')
    `;

    const result = await this.client.query(query, [plzRegion]);
    return parseInt(result.rows[0].total);
  }

  generateSocialProofMessage(projects, totalInRegion, customerPLZ) {
    if (!projects || projects.length === 0) {
      return null;
    }

    const plzRegion = this.getPLZRegion(customerPLZ);
    const projectText = projects.length === 1 ? 'eine Anlage' : `${projects.length} Anlagen`;
    
    const message = `
💡 Lokale Referenzen

Wir haben in PLZ ${plzRegion}xx bereits ${totalInRegion} Anlagen installiert.

${projects.map((p, i) => {
  const city = p.city || p.plz;
  return `📍 ${city}: ${p.system_size_kw} kWp (${new Date(p.installation_date).toLocaleDateString('de-DE')})`;
}).join('\n')}

Unsere Kunden in Ihrer Region vertrauen uns.
    `.trim();

    return message;
  }

  async enrichWhatsAppMessage(leadId, originalMessage) {
    const leadQuery = `
      SELECT plz, city
      FROM leads
      WHERE id = $1
    `;

    const leadResult = await this.client.query(leadQuery, [leadId]);
    
    if (!leadResult.rows[0]) {
      return { message: originalMessage, socialProof: null };
    }

    const { plz, city } = leadResult.rows[0];
    
    const [projects, totalInRegion] = await Promise.all([
      this.findRecentProjectsInPLZ(plz, 3),
      this.countProjectsInPLZ(plz)
    ]);

    if (totalInRegion < 3) {
      return { message: originalMessage, socialProof: null };
    }

    const socialProofMessage = this.generateSocialProofMessage(projects, totalInRegion, plz);
    
    const enrichedMessage = `
${originalMessage}

${socialProofMessage}
    `.trim();

    return {
      message: enrichedMessage,
      socialProof: {
        projects,
        totalInRegion,
        plzRegion: this.getPLZRegion(plz)
      }
    };
  }

  async getProjectPhotosForEmail(plz) {
    const projects = await this.findRecentProjectsInPLZ(plz, 3);
    
    return projects.map(p => ({
      url: p.photo_url,
      city: p.city,
      date: new Date(p.installation_date).toLocaleDateString('de-DE'),
      size: p.system_size_kw
    }));
  }

  async getRegionalStats(plz) {
    const plzRegion = this.getPLZRegion(plz);
    
    const query = `
      SELECT 
        COUNT(*) as total_projects,
        AVG(system_size_kw) as avg_size,
        MIN(installation_date) as first_installation,
        MAX(installation_date) as last_installation
      FROM leads
      WHERE 
        plz LIKE $1 || '%' 
        AND status IN ('completed', 'installation_complete', 'paid')
    `;

    const result = await this.client.query(query, [plzRegion]);
    return result.rows[0];
  }
}

module.exports = SocialProofEnricher;
