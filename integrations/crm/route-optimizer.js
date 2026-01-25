const { calculateDistance } = require('../telegram/maps-link');

function solveTSP(locations) {
  if (locations.length <= 2) return locations;

  const n = locations.length;
  const memo = new Map();

  function dp(pos, visited) {
    const key = `${pos},${visited}`;
    if (memo.has(key)) return memo.get(key);

    if (visited === (1 << n) - 1) {
      return { path: [pos], distance: 0 };
    }

    let minResult = { path: [], distance: Infinity };

    for (let next = 0; next < n; next++) {
      if (!(visited & (1 << next))) {
        const dist = locations[pos].distanceTo[next];
        const result = dp(next, visited | (1 << next));

        const totalDist = dist + result.distance;
        if (totalDist < minResult.distance) {
          minResult = {
            path: [pos, ...result.path],
            distance: totalDist
          };
        }
      }
    }

    memo.set(key, minResult);
    return minResult;
  }

  return dp(0, 1).path;
}

async function buildDistanceMatrix(appointments) {
  const n = appointments.length;
  const matrix = Array(n).fill(null).map(() => Array(n).fill(0));

  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) {
        matrix[i][j] = 0;
      } else {
        const from = appointments[i];
        const to = appointments[j];
        matrix[i][j] = await calculateDistance(
          from.latitude, from.longitude,
          to.latitude, to.longitude
        );
      }
    }
  }

  return matrix;
}

async function optimizeRoute(appointments) {
  if (!appointments || appointments.length < 2) {
    return {
      optimizedRoute: appointments,
      totalDistance: 0,
      savedDistance: 0,
      savingsPercentage: 0
    };
  }

  const distanceMatrix = await buildDistanceMatrix(appointments);

  const locations = appointments.map((apt, index) => ({
    id: apt.id,
    index,
    distanceTo: distanceMatrix[index]
  }));

  const optimalOrder = solveTSP(locations);

  const optimizedRoute = optimalOrder.map(idx => appointments[idx]);

  let optimizedDistance = 0;
  for (let i = 0; i < optimalOrder.length - 1; i++) {
    optimizedDistance += distanceMatrix[optimalOrder[i]][optimalOrder[i + 1]];
  }

  let originalDistance = 0;
  for (let i = 0; i < appointments.length - 1; i++) {
    originalDistance += distanceMatrix[i][i + 1];
  }

  const savedDistance = originalDistance - optimizedDistance;
  const savingsPercentage = originalDistance > 0 
    ? Math.round((savedDistance / originalDistance) * 100) 
    : 0;

  return {
    optimizedRoute,
    totalDistance: Math.round(optimizedDistance * 10) / 10,
    savedDistance: Math.round(savedDistance * 10) / 10,
    savingsPercentage,
    originalDistance: Math.round(originalDistance * 10) / 10
  };
}

function formatRouteSummary(routeResult) {
  const { optimizedRoute, totalDistance, savedDistance, savingsPercentage } = routeResult;
  
  let summary = `🗺️ Optimierte Route\n\n`;
  summary += `Gesamtstrecke: ${totalDistance} km\n`;
  
  if (savedDistance > 0) {
    summary += `Gespart: ${savedDistance} km (${savingsPercentage}%)\n\n`;
  }

  summary += `📍 Haltestellen:\n`;
  optimizedRoute.forEach((apt, index) => {
    summary += `${index + 1}. ${apt.name || apt.address_street} - ${apt.appointment_time || '--:--'}\n`;
  });

  return summary;
}

async function exportToGoogleMaps(routeResult) {
  const { optimizedRoute } = routeResult;
  
  const coordinates = optimizedRoute.map(apt => ({
    lat: apt.latitude,
    lon: apt.longitude
  }));

  const { buildMultiStopRoute } = require('../telegram/maps-link');
  return buildMultiStopRoute(coordinates);
}

module.exports = {
  optimizeRoute,
  formatRouteSummary,
  exportToGoogleMaps
};
