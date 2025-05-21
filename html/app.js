$(function() {
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.type === "open") {
            $('#leaderboard-container').removeClass('hidden');
            populateLeaderboard(data.leaderboard, data.playerStats, data.playerId);
        } else if (data.type === "close") {
            $('#leaderboard-container').addClass('hidden');
        }
    });

    $('.close-btn').click(function() {
        $('#leaderboard-container').addClass('hidden');
        $.post('https://muffin_metaldetecting/close', JSON.stringify({}));
    });

    $('.tab').click(function() {
        const tabId = $(this).data('tab');
        $('.tab').removeClass('active');
        $(this).addClass('active');

        // Update visibility with classes, not CSS transitions
        if (tabId === 'items') {
            $('.items-header').removeClass('hidden');
            $('.value-header').addClass('hidden');
        } else {
            $('.items-header').addClass('hidden');
            $('.value-header').removeClass('hidden');
        }

        // Update the table data based on the selected tab
        updateTableVisibility(tabId);
    });

    // Close on escape key
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            $('#leaderboard-container').addClass('hidden');
            $.post('https://muffin_metaldetecting/close', JSON.stringify({}));
        }
    });
});

function updateTableVisibility(tabId) {
    // Sort the table based on the selected tab
    const rows = $('#leaderboard-body tr').toArray();
    
    rows.sort((a, b) => {
        const aValue = parseInt($(a).data(`${tabId}-value`));
        const bValue = parseInt($(b).data(`${tabId}-value`));
        return bValue - aValue; // Sort in descending order
    });
    
    $('#leaderboard-body').empty();
    
    // Add rows back in sorted order and update ranks
    rows.forEach((row, index) => {
        $(row).find('td:first-child').text(index + 1);
        $(row).find('td:first-child').removeClass('rank-1 rank-2 rank-3');
        if (index < 3) {
            $(row).find('td:first-child').addClass(`rank-${index+1}`);
        }
        $('#leaderboard-body').append(row);
    });
}

function populateLeaderboard(leaderboard, playerStats, playerId) {
    const tbody = $('#leaderboard-body');
    tbody.empty();
    
    // Sort by total items as default
    leaderboard.sort((a, b) => b.totalItems - a.totalItems);
    
    leaderboard.forEach((player, index) => {
        const isCurrentPlayer = player.id === playerId;
        
        const row = $('<tr>')
            .data('items-value', player.totalItems)
            .data('value-value', player.totalValue)
            .addClass(isCurrentPlayer ? 'player-row' : '');
            
        row.append($('<td>').text(index + 1).addClass(index < 3 ? `rank-${index+1}` : ''));
        row.append($('<td>').text(player.name));
        row.append($('<td>').addClass('items-header').text(player.totalItems));
        row.append($('<td>').addClass('value-header hidden').text('$' + player.totalValue.toLocaleString()));
        
        tbody.append(row);
    });

    // Populate player stats with modern design
    const statsContainer = $('#player-stats-content');
    statsContainer.empty();
    
    // Create a table for simplified player stats
    const statsTable = $('<table>').addClass('player-stats-table');
    
    // Basic stats
    statsTable.append($('<tr>').append(
        $('<td>').text('Total Items Found'),
        $('<td>').text(playerStats.totalItems).addClass('highlight-value')
    ));
    
    statsTable.append($('<tr>').append(
        $('<td>').text('Total Value Found'),
        $('<td>').text('$' + playerStats.totalValue.toLocaleString()).addClass('highlight-value')
    ));
    
    // Time stats
    statsTable.append($('<tr>').append(
        $('<td colspan="2">').html('<div class="stat-category">Time Details</div>')
    ));
    
    statsTable.append($('<tr>').append(
        $('<td>').text('Hunting Time'),
        $('<td>').text(formatTime(playerStats.totalTime))
    ));
    
    statsTable.append($('<tr>').append(
        $('<td>').text('Efficiency'),
        $('<td>').text((playerStats.totalTime > 0 ? (playerStats.totalItems / (playerStats.totalTime / 3600)).toFixed(1) : '0.0') + ' items/hour')
    ));
    
    statsContainer.append(statsTable);
}

function formatTime(seconds) {
    if (!seconds || seconds == 0) return '0h 0m';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    return `${hours}h ${minutes}m`;
}