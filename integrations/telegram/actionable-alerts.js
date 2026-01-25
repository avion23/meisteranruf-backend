const axios = require('axios');
const fs = require('fs');
const path = require('path');

let config;
try {
  const configPath = process.env.TELEGRAM_CONFIG_PATH || path.join(__dirname, 'bot-config.json');
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (err) {
  console.error('Config file not found');
  throw err;
}

const API_BASE = `https://api.telegram.org/bot${config.botToken}`;

function escapeMarkdown(text) {
  if (!text) return '';
  return String(text)
    .replace(/_/g, '\\_')
    .replace(/\*/g, '\\*')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)')
    .replace(/~/g, '\\~')
    .replace(/`/g, '\\`')
    .replace(/>/g, '\\>')
    .replace(/#/g, '\\#')
    .replace(/\+/g, '\\+')
    .replace(/-/g, '\\-')
    .replace(/=/g, '\\=')
    .replace(/\|/g, '\\|')
    .replace(/\./g, '\\.')
    .replace(/!/g, '\\!');
}

function buildInlineKeyboard(lead, mapsUrl) {
  const keyboard = {
    inline_keyboard: [
      [
        {
          text: 'Jetzt anrufen 📞',
          url: `tel:${lead.phone}`
        },
        {
          text: 'Google Maps 🗺️',
          url: mapsUrl
        }
      ],
      [
        {
          text: 'Später ⏰',
          callback_data: `remind:${lead.id}`
        },
        {
          text: 'Ablehnen ❌',
          callback_data: `reject:${lead.id}`
        }
      ]
    ]
  };

  if (lead.appointment_today) {
    keyboard.inline_keyboard.push([
      {
        text: 'Termin heute ✅',
        callback_data: `confirm_appointment:${lead.id}`
      }
    ]);
  }

  return keyboard;
}

function buildActionableAlert(lead) {
  const summary = `${escapeMarkdown(lead.name || 'Unbekannt')} | ${escapeMarkdown(String(lead.roof_area_sqm || 0))}m² | ${lead.distance_km ? Math.round(lead.distance_km) : '?'}km | ${lead.is_owner ? 'Eigentümer' : 'Mieter'}`;
  
  let message = `📞 *Neuer Lead*\n\n${summary}`;

  if (lead.appointment_today) {
    message += `\n\n📅 Termin heute: ${escapeMarkdown(lead.appointment_time || 'Zeit vereinbaren')}`;
  }

  if (lead.missed_calls > 1) {
    message += `\n\n⚠️ ${lead.missed_calls}x verpasst`;
  }

  return message;
}

async function sendActionableAlert(chatId, lead, mapsUrl) {
  try {
    const payload = {
      chat_id: chatId,
      text: buildActionableAlert(lead),
      parse_mode: 'MarkdownV2',
      reply_markup: buildInlineKeyboard(lead, mapsUrl),
      disable_web_page_preview: true
    };

    const response = await axios.post(`${API_BASE}/sendMessage`, payload, { timeout: 10000 });
    
    if (!response.data.ok) {
      throw new Error(response.data.description || 'Telegram API error');
    }
    
    return response.data.result;
  } catch (err) {
    throw new Error(`Telegram send failed: ${err.message}`);
  }
}

async function handleCallbackQuery(callbackQuery) {
  const { id, data, message } = callbackQuery;
  const [action, leadId] = data.split(':');

  try {
    let responseText = '';
    let showAlert = false;

    switch (action) {
      case 'remind':
        responseText = '⏰ Erinnerung in 2 Stunden geplant';
        showAlert = true;
        break;
      case 'reject':
        responseText = '❌ Lead abgelehnt';
        showAlert = true;
        break;
      case 'confirm_appointment':
        responseText = '✅ Termin bestätigt';
        showAlert = true;
        break;
      default:
        responseText = 'Aktion ausgeführt';
    }

    await axios.post(`${API_BASE}/answerCallbackQuery`, {
      callback_query_id: id,
      text: responseText,
      show_alert: showAlert
    });

    return { action, leadId, success: true };
  } catch (err) {
    throw new Error(`Callback handler failed: ${err.message}`);
  }
}

module.exports = {
  sendActionableAlert,
  handleCallbackQuery,
  buildInlineKeyboard,
  buildActionableAlert
};
