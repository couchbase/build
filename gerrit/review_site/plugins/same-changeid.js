Gerrit.install(function(self) {
    function createItem(change) {
        var html = '<li><a href="{url}">Change {changeNumber}</a>{info}</li>';
        var data = {
            url: Gerrit.url('/' + change._number),
            changeNumber: change._number,
            info: ' (' + change.project + ', ' + change.status + ')'
        };
        return Gerrit.html(html, data);
    }

    function renderItems(items) {
        var container = document.getElementById('change_plugins');
        var p = Gerrit.html(
            '<p class="{style}">Other commits with same Change-Id:</p>',
            {style: Gerrit.css('margin-bottom: 0;')});
        var list = Gerrit.html(
            '<ul class="{style}"></ul>',
            {style: Gerrit.css('margin-top: 0;')});
        for (var i in items) {
            list.appendChild(items[i]);
        }
        container.appendChild(p);
        container.appendChild(list);
    }

    self.on('showchange', function(currentChange, revisionInfo) {
        var changeId = currentChange.change_id;
        Gerrit.get('/changes/?q=' + changeId, function(resp) {
            // Only render it if there is more than one one project
            // has the same Change-Id
            if (resp.length > 1) {
                var items = [];
                for (var i = 0; i < resp.length; i++) {
                    if (currentChange.id !== resp[i].id) {
                        items.push(createItem(resp[i]));
                    }
                }
                renderItems(items);
            }
        });
    });
});
