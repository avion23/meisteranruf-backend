const body = $input.first().json.body.Body || '';
const phone = $input.first().json.body.From || '';
const normalizedResponse = body.trim().toLowerCase();

// Validate SMS body is not empty
if (!body || body.trim().length === 0) {
  return [{ json: { error: 'Empty SMS body', validationError: true } }];
}

// STOP keyword detection (DSGVO Opt-out)
const stopWords = ['stop', 'abmelden', 'abbestellen', 'ende', 'stopp', 'unsubscribe'];
const isStopRequest = stopWords.some(word => normalizedResponse.includes(word));

if (isStopRequest) {
  return [{ json: { phone: phone.replace(/[^0-9+]/g, ''), response: body, action: 'unsubscribe', isStopRequest: true } }];
}

// Affirmative response detection
const affirmativePatterns = ['ja', 'yes', 'ok', 'okay', 'jaa', 'klar', 'gerne', 'ja bitte'];
const isValidResponse = affirmativePatterns.some(pattern => normalizedResponse.includes(pattern));

// Phone normalization (international support)
let p = phone.replace(/[^0-9+]/g, '');
if (p.startsWith('+')) {
  // Keep international format
} else if (p.startsWith('00')) {
  p = '+' + p.substring(2);
} else if (p.startsWith('0') && p.length >= 10 && p.length <= 13) {
  p = '+49' + p.substring(1);
} else if (!p.startsWith('+') && p.length > 0) {
  p = '+49' + p;
}

// Extract media fields for 3-question flow
const numMedia = parseInt($input.first().json.body.NumMedia || '0');
const mediaUrl0 = $input.first().json.body.MediaUrl0 || null;

// Check 3-question feature flag
const use3Question = $env.ENABLE_3_QUESTION_FLOW === 'true';

return [{ json: { 
  phone: p, 
  response: body, 
  isValidResponse, 
  action: isValidResponse ? 'opt-in' : 'unknown',
  numMedia,
  mediaUrl0,
  use3Question
} }];
