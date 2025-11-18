const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const fs = require('fs');
const path = require('path');
const chokidar = require('chokidar');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const PORT = process.env.PORT || 3000;
const LOG_PATH = process.env.LOG_PATH || '/logs';
const DLP_ALERTS_LOG = path.join(LOG_PATH, 'dlp_alerts.log');

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Store recent alerts in memory
let recentAlerts = [];
let alertStats = {
  total: 0,
  critical: 0,
  high: 0,
  medium: 0,
  low: 0,
  byType: {},
  byDestination: {}  // Track alerts by destination host
};

// Function to parse DLP alert log line (mitmproxy format)
function parseDLPAlert(line) {
  try {
    const alert = JSON.parse(line);
    return alert;
  } catch (e) {
    return null;
  }
}

// Function to update statistics
function updateStats(alert) {
  alertStats.total++;

  const severity = alert.severity.toLowerCase();
  if (alertStats[severity] !== undefined) {
    alertStats[severity]++;
  }

  const type = alert.type;
  alertStats.byType[type] = (alertStats.byType[type] || 0) + 1;

  // Track by destination
  const host = alert.host || 'unknown';
  if (!alertStats.byDestination[host]) {
    alertStats.byDestination[host] = {
      total: 0,
      critical: 0,
      high: 0,
      medium: 0,
      low: 0,
      categories: {}
    };
  }

  alertStats.byDestination[host].total++;
  alertStats.byDestination[host][severity]++;

  // Track categories per destination
  const category = alert.type;
  if (!alertStats.byDestination[host].categories[category]) {
    alertStats.byDestination[host].categories[category] = 0;
  }
  alertStats.byDestination[host].categories[category]++;
}

// Function to read existing alerts on startup
function loadExistingAlerts() {
  if (fs.existsSync(DLP_ALERTS_LOG)) {
    const content = fs.readFileSync(DLP_ALERTS_LOG, 'utf8');
    const lines = content.trim().split('\n').filter(line => line.length > 0);

    console.log(`Total lines in log: ${lines.length}`);

    // Load last 200 alerts
    const recentLines = lines.slice(-200);
    console.log(`Processing last ${recentLines.length} lines`);

    recentLines.forEach(line => {
      const alert = parseDLPAlert(line);
      if (alert) {
        recentAlerts.push(alert);
        updateStats(alert);
      }
    });

    console.log(`Loaded ${recentAlerts.length} existing alerts into memory`);
    console.log(`Stats total: ${alertStats.total}`);
  }
}

// Watch DLP alerts log file for changes
function watchLogFile() {
  const watcher = chokidar.watch(DLP_ALERTS_LOG, {
    persistent: true,
    ignoreInitial: true
  });

  let filePosition = fs.existsSync(DLP_ALERTS_LOG) ? fs.statSync(DLP_ALERTS_LOG).size : 0;

  watcher.on('change', () => {
    const stats = fs.statSync(DLP_ALERTS_LOG);
    if (stats.size > filePosition) {
      const stream = fs.createReadStream(DLP_ALERTS_LOG, {
        start: filePosition,
        end: stats.size,
        encoding: 'utf8'
      });

      let buffer = '';
      stream.on('data', chunk => {
        buffer += chunk;
        const lines = buffer.split('\n');
        buffer = lines.pop();

        lines.forEach(line => {
          if (line.trim()) {
            const alert = parseDLPAlert(line);
            if (alert) {
              recentAlerts.push(alert);
              updateStats(alert);

              // Keep only last 200 alerts in memory
              if (recentAlerts.length > 200) {
                recentAlerts.shift();
              }

              // Emit to all connected clients
              io.emit('newAlert', alert);
              io.emit('statsUpdate', alertStats);
            }
          }
        });
      });

      filePosition = stats.size;
    }
  });

  console.log('Watching DLP alerts log file for changes...');
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('New client connected');

  // Send current statistics and recent alerts to new client
  socket.emit('initialData', {
    alerts: recentAlerts,
    stats: alertStats
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

// API endpoint to get current statistics
app.get('/api/stats', (req, res) => {
  res.json({
    ...alertStats,
    alerts: recentAlerts  // Include alerts in stats response
  });
});

// API endpoint to get recent alerts
app.get('/api/alerts', (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  res.json(recentAlerts.slice(-limit));
});

// API endpoint to get alerts by severity
app.get('/api/alerts/severity/:severity', (req, res) => {
  const severity = req.params.severity.toLowerCase();
  const filtered = recentAlerts.filter(alert =>
    alert.severity.toLowerCase() === severity
  );
  res.json(filtered);
});

// Start server
server.listen(PORT, () => {
  console.log(`DLP Dashboard server running on port ${PORT}`);

  // Create logs directory if it doesn't exist
  if (!fs.existsSync(LOG_PATH)) {
    fs.mkdirSync(LOG_PATH, { recursive: true });
  }

  // Load existing alerts
  loadExistingAlerts();

  // Start watching log file
  watchLogFile();
});
