// Connect to Socket.IO server
const socket = io();

// State management
let allAlerts = [];
let currentFilter = 'all';
let destinationFilter = null;
let typeFilter = null;

// DOM elements
const connectionStatus = document.getElementById('connection-status');
const lastUpdate = document.getElementById('last-update');
const totalAlertsEl = document.getElementById('total-alerts');
const criticalAlertsEl = document.getElementById('critical-alerts');
const highAlertsEl = document.getElementById('high-alerts');
const mediumAlertsEl = document.getElementById('medium-alerts');
const lowAlertsEl = document.getElementById('low-alerts');
const typeChart = document.getElementById('type-chart');
const destinationsGrid = document.getElementById('destinations-grid');
const alertsContainer = document.getElementById('alerts-container');
const filterButtons = document.querySelectorAll('.filter-btn');
const modal = document.getElementById('alert-modal');
const modalBody = document.getElementById('modal-body');
const modalClose = document.querySelector('.modal-close');
const filterBadge = document.getElementById('filter-badge');
const filterBadgeText = document.getElementById('filter-badge-text');
const clearFilterBtn = document.getElementById('clear-filter');

// Socket event handlers
socket.on('connect', () => {
    connectionStatus.textContent = 'Connected';
    connectionStatus.classList.remove('disconnected');
    connectionStatus.classList.add('connected');
    console.log('Connected to server');
});

socket.on('disconnect', () => {
    connectionStatus.textContent = 'Disconnected';
    connectionStatus.classList.remove('connected');
    connectionStatus.classList.add('disconnected');
    console.log('Disconnected from server');
});

socket.on('initialData', (data) => {
    console.log('=== INITIAL DATA RECEIVED ===');
    console.log('Data object:', data);
    console.log('Alerts array length:', data.alerts ? data.alerts.length : 0);
    console.log('Stats:', data.stats);

    allAlerts = data.alerts || [];
    console.log('allAlerts set to:', allAlerts.length, 'alerts');

    updateStatistics(data.stats);
    renderAlerts();
    updateLastUpdate();

    console.log('=== INITIAL DATA PROCESSED ===');
});

socket.on('newAlert', (alert) => {
    console.log('New alert received', alert);
    allAlerts.push(alert);

    // Keep only last 200 alerts
    if (allAlerts.length > 200) {
        allAlerts.shift();
    }

    renderAlerts();
    updateLastUpdate();

    // Play alert sound or show notification (optional)
    showNotification(alert);
});

socket.on('statsUpdate', (stats) => {
    updateStatistics(stats);
});

// Show notification for new alert
function showNotification(alert) {
    // Add a brief flash animation to the relevant severity card
    const severityCard = document.querySelector(`.stat-card.${alert.severity.toLowerCase()}`);
    if (severityCard) {
        severityCard.classList.add('flash');
        setTimeout(() => severityCard.classList.remove('flash'), 1000);
    }
}

// Update statistics display
function updateStatistics(stats) {
    totalAlertsEl.textContent = stats.total || 0;
    criticalAlertsEl.textContent = stats.critical || 0;
    highAlertsEl.textContent = stats.high || 0;
    mediumAlertsEl.textContent = stats.medium || 0;
    lowAlertsEl.textContent = stats.low || 0;

    renderTypeChart(stats.byType);
    renderDestinations(stats.byDestination);
}

// Render type chart
function renderTypeChart(byType) {
    if (!byType || Object.keys(byType).length === 0) {
        typeChart.innerHTML = '<p class="no-data">No data patterns detected yet</p>';
        return;
    }

    typeChart.innerHTML = '';

    // Sort by count descending
    const sorted = Object.entries(byType).sort((a, b) => b[1] - a[1]);

    sorted.forEach(([type, count]) => {
        const item = document.createElement('div');
        item.className = 'type-item';
        item.innerHTML = `
            <div class="type-name">${formatTypeName(type)}</div>
            <div class="type-count">${count}</div>
        `;

        // Add click handler to filter by type
        item.addEventListener('click', () => {
            typeFilter = type;
            renderAlerts();
            // Scroll to alerts section
            document.querySelector('.alerts-section').scrollIntoView({ behavior: 'smooth' });
        });

        typeChart.appendChild(item);
    });
}

// Format type name for display
function formatTypeName(type) {
    // Convert snake_case or kebab-case to Title Case
    return type
        .replace(/_/g, ' ')
        .replace(/-/g, ' ')
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');
}

// Render destinations
function renderDestinations(byDestination) {
    if (!byDestination || Object.keys(byDestination).length === 0) {
        destinationsGrid.innerHTML = '<p class="no-destinations">No destinations tracked yet</p>';
        return;
    }

    destinationsGrid.innerHTML = '';

    // Sort by total alerts descending
    const sorted = Object.entries(byDestination).sort((a, b) => b[1].total - a[1].total);

    sorted.forEach(([host, data]) => {
        const card = createDestinationCard(host, data);
        destinationsGrid.appendChild(card);
    });
}

// Create destination card element
function createDestinationCard(host, data) {
    const card = document.createElement('div');
    card.className = 'destination-card';

    // Sort categories by count
    const categories = Object.entries(data.categories || {})
        .sort((a, b) => b[1] - a[1]);

    const categoriesHtml = categories.length > 0 ? `
        <div class="destination-categories">
            <div class="destination-categories-title">Data Categories</div>
            <div class="category-tags">
                ${categories.map(([cat, count]) => `
                    <div class="category-tag">
                        <span>${formatTypeName(cat)}</span>
                        <span class="category-tag-count">${count}</span>
                    </div>
                `).join('')}
            </div>
        </div>
    ` : '';

    card.innerHTML = `
        <div class="destination-header">
            <div class="destination-host">${escapeHtml(host)}</div>
            <div class="destination-total">${data.total}</div>
        </div>
        <div class="destination-severity-stats">
            <div class="severity-stat critical">
                <div class="severity-stat-label">Critical</div>
                <div class="severity-stat-value">${data.critical || 0}</div>
            </div>
            <div class="severity-stat high">
                <div class="severity-stat-label">High</div>
                <div class="severity-stat-value">${data.high || 0}</div>
            </div>
            <div class="severity-stat medium">
                <div class="severity-stat-label">Medium</div>
                <div class="severity-stat-value">${data.medium || 0}</div>
            </div>
            <div class="severity-stat low">
                <div class="severity-stat-label">Low</div>
                <div class="severity-stat-value">${data.low || 0}</div>
            </div>
        </div>
        ${categoriesHtml}
    `;

    // Add click handler to filter by destination
    card.addEventListener('click', () => {
        destinationFilter = host;
        renderAlerts();
        // Scroll to alerts section
        document.querySelector('.alerts-section').scrollIntoView({ behavior: 'smooth' });
    });

    return card;
}

// Filter alerts based on current filter
function getFilteredAlerts() {
    let filtered = allAlerts;

    // Apply severity filter
    if (currentFilter !== 'all') {
        filtered = filtered.filter(alert => alert.severity.toLowerCase() === currentFilter);
    }

    // Apply destination filter
    if (destinationFilter) {
        filtered = filtered.filter(alert => alert.host === destinationFilter);
    }

    // Apply type filter
    if (typeFilter) {
        filtered = filtered.filter(alert => alert.type === typeFilter);
    }

    // Update filter badge
    updateFilterBadge();

    return filtered;
}

// Render alerts to the DOM
function renderAlerts() {
    console.log('=== RENDER ALERTS CALLED ===');
    console.log('allAlerts length:', allAlerts.length);

    const filteredAlerts = getFilteredAlerts();
    console.log('filteredAlerts length:', filteredAlerts.length);

    if (filteredAlerts.length === 0) {
        console.log('No alerts to render - showing placeholder');
        alertsContainer.innerHTML = '<div class="no-alerts"><p>No alerts to display</p><p class="hint">Alerts will appear here when sensitive data is detected</p></div>';
        return;
    }

    // Reverse to show newest first
    const alertsToRender = [...filteredAlerts].reverse();
    console.log('Rendering', alertsToRender.length, 'alerts');

    alertsContainer.innerHTML = '';

    alertsToRender.forEach(alert => {
        const alertCard = createAlertCard(alert);
        alertsContainer.appendChild(alertCard);
    });

    console.log('=== ALERTS RENDERED ===');
}

// Create alert card element
function createAlertCard(alert) {
    const card = document.createElement('div');
    const severity = alert.severity.toLowerCase();
    card.className = `alert-card ${severity}`;

    // Format timestamp
    const timestamp = new Date(alert.timestamp).toLocaleString();

    // Get direction icon
    const directionIcon = alert.direction === 'request' ? '↑' : '↓';
    const directionLabel = alert.direction === 'request' ? 'Outbound' : 'Inbound';

    card.innerHTML = `
        <div class="alert-header">
            <div class="alert-severity-badge ${severity}">${alert.severity.toUpperCase()}</div>
            <span class="alert-time">${timestamp}</span>
        </div>
        <div class="alert-body">
            <div class="alert-main-info">
                <div class="detection-type">${formatTypeName(alert.type)}</div>
                <div class="alert-url" title="${alert.url}">${truncateUrl(alert.url)}</div>
            </div>
            <div class="alert-details">
                <div class="detail-row">
                    <span class="detail-label">Direction:</span>
                    <span class="detail-value">${directionIcon} ${directionLabel}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Method:</span>
                    <span class="detail-value method-badge">${alert.method}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Host:</span>
                    <span class="detail-value">${alert.host}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Source IP:</span>
                    <span class="detail-value">${alert.source_ip}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Matches:</span>
                    <span class="detail-value">${alert.matches_count}</span>
                </div>
            </div>
            ${alert.sample ? `
                <div class="alert-sample">
                    <div class="sample-label">Sample:</div>
                    <code class="sample-content">${escapeHtml(alert.sample)}</code>
                </div>
            ` : ''}
        </div>
    `;

    // Add click handler to open modal
    card.addEventListener('click', () => {
        openModal(alert);
    });

    return card;
}

// Truncate URL for display
function truncateUrl(url, maxLength = 80) {
    if (url.length <= maxLength) return url;
    return url.substring(0, maxLength) + '...';
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Update last update time
function updateLastUpdate() {
    const now = new Date();
    lastUpdate.textContent = `Last update: ${now.toLocaleTimeString()}`;
}

// Filter button event listeners
filterButtons.forEach(button => {
    button.addEventListener('click', () => {
        filterButtons.forEach(btn => btn.classList.remove('active'));
        button.classList.add('active');
        currentFilter = button.dataset.filter;
        renderAlerts();
    });
});

// Auto-refresh stats every 30 seconds
setInterval(() => {
    fetch('/api/stats')
        .then(res => res.json())
        .then(stats => updateStatistics(stats))
        .catch(err => console.error('Failed to fetch stats:', err));
}, 30000);

// Update filter badge
function updateFilterBadge() {
    const filters = [];

    if (destinationFilter) filters.push(`Destination: ${destinationFilter}`);
    if (typeFilter) filters.push(`Type: ${formatTypeName(typeFilter)}`);
    if (currentFilter !== 'all') filters.push(`Severity: ${currentFilter.toUpperCase()}`);

    if (filters.length > 0) {
        filterBadgeText.textContent = filters.join(' | ');
        filterBadge.style.display = 'flex';
    } else {
        filterBadge.style.display = 'none';
    }
}

// Clear all filters
clearFilterBtn.addEventListener('click', () => {
    destinationFilter = null;
    typeFilter = null;
    currentFilter = 'all';

    // Reset severity filter buttons
    filterButtons.forEach(btn => btn.classList.remove('active'));
    document.querySelector('[data-filter="all"]').classList.add('active');

    renderAlerts();
});

// Modal functions
function openModal(alert) {
    const severity = alert.severity.toLowerCase();
    const directionIcon = alert.direction === 'request' ? '↑' : '↓';
    const directionLabel = alert.direction === 'request' ? 'Outbound' : 'Inbound';

    modalBody.innerHTML = `
        <div class="modal-section">
            <div class="modal-section-title">Alert Information</div>
            <div class="modal-data-grid">
                <div class="modal-data-label">Severity:</div>
                <div class="modal-data-value">
                    <span class="alert-severity-badge ${severity}">${alert.severity.toUpperCase()}</span>
                </div>

                <div class="modal-data-label">Detection Type:</div>
                <div class="modal-data-value">${formatTypeName(alert.type)}</div>

                <div class="modal-data-label">Timestamp:</div>
                <div class="modal-data-value">${new Date(alert.timestamp).toLocaleString()}</div>

                <div class="modal-data-label">Direction:</div>
                <div class="modal-data-value">${directionIcon} ${directionLabel}</div>

                <div class="modal-data-label">Method:</div>
                <div class="modal-data-value"><span class="method-badge">${alert.method}</span></div>

                <div class="modal-data-label">Destination Host:</div>
                <div class="modal-data-value">${escapeHtml(alert.host)}</div>

                <div class="modal-data-label">Source IP:</div>
                <div class="modal-data-value">${alert.source_ip}</div>

                <div class="modal-data-label">Matches Count:</div>
                <div class="modal-data-value">${alert.matches_count}</div>
            </div>
        </div>

        <div class="modal-section">
            <div class="modal-section-title">Request URL</div>
            <div class="modal-code-block">
                <pre>${escapeHtml(alert.url)}</pre>
            </div>
        </div>

        ${alert.sample ? `
            <div class="modal-section">
                <div class="modal-section-title">Detected Sample</div>
                <div class="modal-code-block">
                    <pre>${escapeHtml(alert.sample)}</pre>
                </div>
            </div>
        ` : ''}

        <div class="modal-section">
            <div class="modal-section-title">Raw Alert Data</div>
            <div class="modal-code-block">
                <pre>${JSON.stringify(alert, null, 2)}</pre>
            </div>
        </div>
    `;

    modal.classList.add('active');
}

function closeModal() {
    modal.classList.remove('active');
}

// Modal event listeners
modalClose.addEventListener('click', closeModal);

modal.addEventListener('click', (e) => {
    if (e.target === modal) {
        closeModal();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modal.classList.contains('active')) {
        closeModal();
    }
});

// Initialize
updateLastUpdate();
