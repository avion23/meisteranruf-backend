function shouldCallNow(lead) {
  const goodSize = (lead.roof_area_sqm || 0) > 40;
  const nearBy = (lead.distance_km || Infinity) < 50;
  const isOwner = lead.is_owner === true;
  const urgent = (lead.missed_calls || 0) > 1;

  return (goodSize && nearBy && isOwner) || urgent;
}

function shouldCallLater(lead) {
  const decentSize = (lead.roof_area_sqm || 0) > 20;
  const reasonableDistance = (lead.distance_km || Infinity) < 100;
  const hasInterest = lead.interested === true;

  return decentSize && reasonableDistance && hasInterest;
}

function getCallAction(lead) {
  if (shouldCallNow(lead)) {
    return 'call_now';
  }
  if (shouldCallLater(lead)) {
    return 'call_later';
  }
  return 'skip';
}

function formatLeadSummary(lead) {
  const name = lead.name || 'Unbekannt';
  const roofArea = lead.roof_area_sqm || 0;
  const distance = lead.distance_km ? Math.round(lead.distance_km) : '?';
  const status = lead.is_owner ? 'Eigentümer' : 'Mieter';

  return `${name} | ${roofArea}m² | ${distance}km | ${status}`;
}

module.exports = {
  shouldCallNow,
  shouldCallLater,
  getCallAction,
  formatLeadSummary
};
