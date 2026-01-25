function buildGoogleMapsLink(lat, lon) {
  if (!lat || !lon) return null;
  return `https://maps.google.com/?q=${lat},${lon}`;
}

function buildDirectionsLink(fromLat, fromLon, toLat, toLon) {
  if (!fromLat || !fromLon || !toLat || !toLon) return null;
  return `https://www.google.com/maps/dir/${fromLat},${fromLon}/${toLat},${toLon}`;
}

function buildMultiStopRoute(coordinates) {
  if (!coordinates || coordinates.length === 0) return null;
  
  const points = coordinates.map(c => `${c.lat},${c.lon}`).join('/');
  return `https://www.google.com/maps/dir/${points}`;
}

function buildClusterMapUrl(leads) {
  if (!leads || leads.length === 0) return null;

  const validLeads = leads.filter(l => l.latitude && l.longitude);
  if (validLeads.length === 0) return null;

  const centerLat = validLeads.reduce((sum, l) => sum + parseFloat(l.latitude), 0) / validLeads.length;
  const centerLon = validLeads.reduce((sum, l) => sum + parseFloat(l.longitude), 0) / validLeads.length;

  const zoom = validLeads.length > 10 ? 11 : 13;
  return `https://www.google.com/maps/@${centerLat},${centerLon},${zoom}z`;
}

async function calculateDistance(fromLat, fromLon, toLat, toLon) {
  const R = 6371;
  const dLat = toRad(toLat - fromLat);
  const dLon = toRad(toLon - fromLon);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(fromLat)) * Math.cos(toRad(toLat)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

async function estimateDrivingTime(fromLat, fromLon, toLat, toLon) {
  const distance = await calculateDistance(fromLat, fromLon, toLat, toLon);
  const avgSpeedKmh = 50;
  const timeMinutes = (distance / avgSpeedKmh) * 60;
  
  const hours = Math.floor(timeMinutes / 60);
  const minutes = Math.round(timeMinutes % 60);
  
  if (hours > 0) {
    return `${hours}h ${minutes}min`;
  }
  return `${minutes}min`;
}

module.exports = {
  buildGoogleMapsLink,
  buildDirectionsLink,
  buildMultiStopRoute,
  buildClusterMapUrl,
  calculateDistance,
  estimateDrivingTime
};
