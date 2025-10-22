// GitLab CI Pipelines Exporter Dashboard JavaScript
class GitLabDashboard {
    constructor() {
        this.autoRefreshInterval = null;
        this.refreshRate = 30000; // 30 seconds
        this.isAutoRefresh = false;
        this.projects = new Set();
        this.branches = new Set();
        this.pipelines = [];
        this.environments = [];

        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadData();
        this.updateConnectionStatus('connecting');
    }

    setupEventListeners() {
        // Refresh button
        document.getElementById('refresh-btn').addEventListener('click', () => {
            this.loadData();
        });

        // Auto refresh toggle
        document.getElementById('auto-refresh-toggle').addEventListener('click', () => {
            this.toggleAutoRefresh();
        });

        // Filter event listeners
        document.getElementById('project-filter').addEventListener('change', () => {
            this.applyFilters();
        });

        document.getElementById('branch-filter').addEventListener('change', () => {
            this.applyFilters();
        });

        document.getElementById('status-filter').addEventListener('change', () => {
            this.applyFilters();
        });
    }

    async loadData() {
        try {
            this.updateConnectionStatus('connecting');

            // Fetch metrics from the Prometheus endpoint
            const response = await fetch('/metrics');

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const metricsText = await response.text();

            // Parse Prometheus metrics
            this.parseMetrics(metricsText);

            // Update UI
            this.updateUI();
            this.updateConnectionStatus('connected');
            this.updateLastUpdated();

        } catch (error) {
            console.error('Error loading data:', error);
            this.updateConnectionStatus('disconnected');
            this.showError('Failed to load data: ' + error.message);
        }
    }

    parseMetrics(metricsText) {
        const lines = metricsText.split('\n');
        const pipelineMetrics = {};
        const environmentMetrics = {};

        // Reset collections
        this.projects.clear();
        this.branches.clear();
        this.pipelines = [];
        this.environments = [];

        lines.forEach(line => {
            if (line.startsWith('#') || line.trim() === '') return;

            // Parse pipeline status metrics
            if (line.includes('gitlab_ci_pipeline_last_run_status')) {
                const match = line.match(/gitlab_ci_pipeline_last_run_status\{([^}]+)\}\s+(\d+)/);
                if (match) {
                    const labels = this.parseLabels(match[1]);
                    const status = this.getStatusFromValue(parseInt(match[2]));

                    const pipeline = {
                        project: labels.project || 'Unknown',
                        ref: labels.ref || 'Unknown',
                        status: status,
                        id: labels.id || Math.random().toString(36).substr(2, 9)
                    };

                    this.projects.add(pipeline.project);
                    this.branches.add(pipeline.ref);
                    this.pipelines.push(pipeline);
                }
            }

            // Parse pipeline duration metrics
            if (line.includes('gitlab_ci_pipeline_last_run_duration_seconds')) {
                const match = line.match(/gitlab_ci_pipeline_last_run_duration_seconds\{([^}]+)\}\s+([\d.]+)/);
                if (match) {
                    const labels = this.parseLabels(match[1]);
                    const duration = parseFloat(match[2]);

                    // Find corresponding pipeline and add duration
                    const pipeline = this.pipelines.find(p =>
                        p.project === labels.project &&
                        p.ref === labels.ref &&
                        p.id === labels.id
                    );
                    if (pipeline) {
                        pipeline.duration = duration;
                    }
                }
            }

            // Parse pipeline timestamp
            if (line.includes('gitlab_ci_pipeline_timestamp')) {
                const match = line.match(/gitlab_ci_pipeline_timestamp\{([^}]+)\}\s+([\d.]+)/);
                if (match) {
                    const labels = this.parseLabels(match[1]);
                    const timestamp = parseFloat(match[2]);

                    // Find corresponding pipeline and add timestamp
                    const pipeline = this.pipelines.find(p =>
                        p.project === labels.project &&
                        p.ref === labels.ref &&
                        p.id === labels.id
                    );
                    if (pipeline) {
                        pipeline.timestamp = new Date(timestamp * 1000);
                    }
                }
            }

            // Parse environment metrics
            if (line.includes('gitlab_ci_environment_information')) {
                const match = line.match(/gitlab_ci_environment_information\{([^}]+)\}\s+(\d+)/);
                if (match) {
                    const labels = this.parseLabels(match[1]);

                    const environment = {
                        project: labels.project || 'Unknown',
                        name: labels.environment || 'Unknown',
                        external_url: labels.external_url || '',
                        available: parseInt(match[2]) === 1
                    };

                    this.environments.push(environment);
                }
            }
        });

        // Update project and branch filters
        this.updateFilters();
    }

    parseLabels(labelString) {
        const labels = {};
        const matches = labelString.match(/(\w+)="([^"]*)"/g);

        if (matches) {
            matches.forEach(match => {
                const [, key, value] = match.match(/(\w+)="([^"]*)"/);
                labels[key] = value;
            });
        }

        return labels;
    }

    getStatusFromValue(value) {
        const statusMap = {
            0: 'success',
            1: 'failed',
            2: 'canceled',
            3: 'skipped',
            4: 'running',
            5: 'pending',
            6: 'created'
        };
        return statusMap[value] || 'unknown';
    }

    updateFilters() {
        // Update project filter
        const projectFilter = document.getElementById('project-filter');
        const currentProjects = Array.from(projectFilter.selectedOptions).map(o => o.value);

        projectFilter.innerHTML = '<option value="">All Projects</option>';
        Array.from(this.projects).sort().forEach(project => {
            const option = document.createElement('option');
            option.value = project;
            option.textContent = project;
            if (currentProjects.includes(project)) {
                option.selected = true;
            }
            projectFilter.appendChild(option);
        });

        // Update branch filter (keep existing options and add new ones)
        const branchFilter = document.getElementById('branch-filter');
        const currentBranches = Array.from(branchFilter.selectedOptions).map(o => o.value);

        // Add any new branches that weren't in the default list
        Array.from(this.branches).forEach(branch => {
            const existingOption = Array.from(branchFilter.options).find(o => o.value === branch);
            if (!existingOption && branch !== '') {
                const option = document.createElement('option');
                option.value = branch;
                option.textContent = branch;
                if (currentBranches.includes(branch)) {
                    option.selected = true;
                }
                branchFilter.appendChild(option);
            }
        });
    }

    applyFilters() {
        const projectFilter = Array.from(document.getElementById('project-filter').selectedOptions).map(o => o.value);
        const branchFilter = Array.from(document.getElementById('branch-filter').selectedOptions).map(o => o.value);
        const statusFilter = document.getElementById('status-filter').value;

        // Filter pipelines
        let filteredPipelines = this.pipelines.filter(pipeline => {
            const projectMatch = projectFilter.length === 0 || projectFilter.includes('') || projectFilter.includes(pipeline.project);
            const branchMatch = branchFilter.length === 0 || branchFilter.includes('') || branchFilter.includes(pipeline.ref);
            const statusMatch = statusFilter === '' || pipeline.status === statusFilter;

            return projectMatch && branchMatch && statusMatch;
        });

        // Filter environments
        let filteredEnvironments = this.environments.filter(env => {
            const projectMatch = projectFilter.length === 0 || projectFilter.includes('') || projectFilter.includes(env.project);
            return projectMatch;
        });

        this.renderPipelines(filteredPipelines);
        this.renderEnvironments(filteredEnvironments);
        this.updateStats(filteredPipelines);
        this.updateMetrics(filteredPipelines);
    }

    updateUI() {
        this.applyFilters();
    }

    renderPipelines(pipelines) {
        const container = document.getElementById('pipelines-container');

        if (pipelines.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-search"></i>
                    <h3>No pipelines found</h3>
                    <p>Try adjusting your filters or check if the exporter is properly configured.</p>
                </div>
            `;
            return;
        }

        // Sort by timestamp (newest first)
        pipelines.sort((a, b) => {
            const timeA = a.timestamp ? a.timestamp.getTime() : 0;
            const timeB = b.timestamp ? b.timestamp.getTime() : 0;
            return timeB - timeA;
        });

        container.innerHTML = pipelines.map(pipeline => `
            <div class="pipeline-item ${pipeline.status}">
                <div class="pipeline-header">
                    <div class="pipeline-title">${pipeline.project} / ${pipeline.ref}</div>
                    <div class="pipeline-status ${pipeline.status}">
                        <i class="fas fa-${this.getStatusIcon(pipeline.status)}"></i>
                        ${pipeline.status}
                    </div>
                </div>
                <div class="pipeline-details">
                    <div class="pipeline-detail">
                        <i class="fas fa-hashtag"></i>
                        ID: ${pipeline.id}
                    </div>
                    <div class="pipeline-detail">
                        <i class="fas fa-clock"></i>
                        ${pipeline.duration ? this.formatDuration(pipeline.duration) : 'N/A'}
                    </div>
                    <div class="pipeline-detail">
                        <i class="fas fa-calendar"></i>
                        ${pipeline.timestamp ? this.formatTimestamp(pipeline.timestamp) : 'N/A'}
                    </div>
                </div>
            </div>
        `).join('');
    }

    renderEnvironments(environments) {
        const container = document.getElementById('environments-container');

        if (environments.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-server"></i>
                    <h3>No environments found</h3>
                    <p>No deployment environments are currently being monitored.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = environments.map(env => `
            <div class="environment-item ${env.available ? 'success' : 'failed'}">
                <div class="pipeline-header">
                    <div class="pipeline-title">${env.project}</div>
                    <div class="pipeline-status ${env.available ? 'success' : 'failed'}">
                        <i class="fas fa-${env.available ? 'check-circle' : 'times-circle'}"></i>
                        ${env.available ? 'Available' : 'Unavailable'}
                    </div>
                </div>
                <div class="pipeline-details">
                    <div class="pipeline-detail">
                        <i class="fas fa-tag"></i>
                        ${env.name}
                    </div>
                    ${env.external_url ? `
                        <div class="pipeline-detail">
                            <i class="fas fa-external-link-alt"></i>
                            <a href="${env.external_url}" target="_blank">View</a>
                        </div>
                    ` : ''}
                </div>
            </div>
        `).join('');
    }

    updateStats(pipelines) {
        const stats = {
            success: pipelines.filter(p => p.status === 'success').length,
            failed: pipelines.filter(p => p.status === 'failed').length,
            running: pipelines.filter(p => p.status === 'running').length,
            pending: pipelines.filter(p => p.status === 'pending').length
        };

        document.getElementById('success-count').textContent = stats.success;
        document.getElementById('failed-count').textContent = stats.failed;
        document.getElementById('running-count').textContent = stats.running;
        document.getElementById('pending-count').textContent = stats.pending;
    }

    updateMetrics(pipelines) {
        const totalPipelines = pipelines.length;
        const successfulPipelines = pipelines.filter(p => p.status === 'success').length;
        const successRate = totalPipelines > 0 ? Math.round((successfulPipelines / totalPipelines) * 100) : 0;

        const durationsInMinutes = pipelines
            .filter(p => p.duration)
            .map(p => p.duration / 60);

        const avgDuration = durationsInMinutes.length > 0
            ? Math.round(durationsInMinutes.reduce((a, b) => a + b, 0) / durationsInMinutes.length)
            : 0;

        document.getElementById('success-rate').textContent = `${successRate}%`;
        document.getElementById('avg-duration').textContent = `${avgDuration}m`;
        document.getElementById('total-projects').textContent = this.projects.size;
        document.getElementById('active-branches').textContent = this.branches.size;
    }

    getStatusIcon(status) {
        const icons = {
            success: 'check-circle',
            failed: 'times-circle',
            running: 'play-circle',
            pending: 'clock',
            canceled: 'ban',
            skipped: 'forward'
        };
        return icons[status] || 'question-circle';
    }

    formatDuration(seconds) {
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = Math.floor(seconds % 60);
        return `${minutes}m ${remainingSeconds}s`;
    }

    formatTimestamp(timestamp) {
        const now = new Date();
        const diff = now - timestamp;

        if (diff < 60000) { // Less than 1 minute
            return 'Just now';
        } else if (diff < 3600000) { // Less than 1 hour
            const minutes = Math.floor(diff / 60000);
            return `${minutes}m ago`;
        } else if (diff < 86400000) { // Less than 1 day
            const hours = Math.floor(diff / 3600000);
            return `${hours}h ago`;
        } else {
            return timestamp.toLocaleDateString();
        }
    }

    toggleAutoRefresh() {
        const button = document.getElementById('auto-refresh-toggle');

        if (this.isAutoRefresh) {
            // Stop auto refresh
            clearInterval(this.autoRefreshInterval);
            this.isAutoRefresh = false;
            button.innerHTML = '<i class="fas fa-play"></i> Auto Refresh';
            button.classList.remove('active');
        } else {
            // Start auto refresh
            this.autoRefreshInterval = setInterval(() => {
                this.loadData();
            }, this.refreshRate);
            this.isAutoRefresh = true;
            button.innerHTML = '<i class="fas fa-pause"></i> Auto Refresh';
            button.classList.add('active');
        }
    }

    updateConnectionStatus(status) {
        const statusElement = document.getElementById('connection-status');
        const statusMap = {
            connected: { class: 'connected', text: 'Connected', icon: 'check-circle' },
            connecting: { class: 'disconnected', text: 'Connecting...', icon: 'spinner fa-spin' },
            disconnected: { class: 'disconnected', text: 'Disconnected', icon: 'times-circle' }
        };

        const statusInfo = statusMap[status];
        statusElement.className = `status ${statusInfo.class}`;
        statusElement.innerHTML = `<i class="fas fa-${statusInfo.icon}"></i> ${statusInfo.text}`;
    }

    updateLastUpdated() {
        const now = new Date();
        document.getElementById('last-updated').textContent =
            `Last updated: ${now.toLocaleTimeString()}`;
    }

    showError(message) {
        // You could implement a toast notification or modal here
        console.error(message);

        // For now, update the pipelines container with error message
        const container = document.getElementById('pipelines-container');
        container.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-exclamation-triangle" style="color: var(--error-color);"></i>
                <h3>Error Loading Data</h3>
                <p>${message}</p>
                <button onclick="dashboard.loadData()" class="btn btn-primary" style="margin-top: 15px;">
                    <i class="fas fa-sync-alt"></i> Retry
                </button>
            </div>
        `;
    }
}

// Initialize the dashboard when the page loads
let dashboard;
document.addEventListener('DOMContentLoaded', () => {
    dashboard = new GitLabDashboard();
});
