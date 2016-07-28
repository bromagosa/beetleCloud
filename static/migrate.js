var projectListDiv = document.getElementById('project-list'),
    importResultDiv = document.getElementById('import-result');

SnapCloud = new Cloud('https://snap.apps.miosoft.com/SnapCloudLocal');

function login() {
    var username = document.getElementsByName('username')[0].value,
    password = hex_sha512(document.getElementsByName('password')[0].value);

    SnapCloud.login(username, password, showProjectList, alert);
    document.getElementById('login').appendChild(document.createTextNode('Logging in...'));
};

function showProjectList() {
    document.getElementById('login').remove();
    projectListDiv.style.display = 'block';

    SnapCloud.getProjectList(function (projects) { 
        document.getElementById('loading').remove();
        projects.forEach(
                function (project) {
                    var option = document.createElement('label');
                    option.innerHTML = '<input id="' + project.ProjectName + '" type="checkbox">' + project.ProjectName;
                    projectListDiv.children[1].appendChild(option);
                });
    });
};

function fetch () {
    var projectNames = [];

    projectListDiv.style.display = 'none';
    importResultDiv.style.display = 'block';

    log('Beginning automatic migration process...');
    log('---');

    [].forEach.call(
            projectListDiv.getElementsByTagName('input'),
            function (input) { if (input.checked) { projectNames.push(input.id) } });

    // Begin recursively fetching projects.
    // We can't do this iteratively because the Snap! Cloud prevents users from
    // fetching two projects at the same time

    doFetch(0);

    function doFetch (index) {
        if (index == projectNames.length) {
            log('Migration finished.');
            return;
        } else {
            try {
                SnapCloud.reconnect(
                        function () {
                            log('Fetching ' + projectNames[index] + '...');
                            SnapCloud.callService(
                                    'getRawProject',
                                    function (response) {
                                        SnapCloud.callService(
                                                'logout',
                                                function () { doFetch(index + 1); },
                                                log
                                                );
                                        SnapCloud.disconnect();
                                        migrate(projectNames[index], response);
                                    },
                                    log,
                                    [projectNames[index]]
                                    );
                        },
                        log
                        );
            } catch(err) {
                log('*** Cloud Error! ***');
                log('Ignoring project.');
                log('---');
                doFetch(index + 1);
            }
        }
    }

};

function migrate (projectName, rawProject) {
    var ajax = new XMLHttpRequest();

    log('Migrating ' + projectName + '...');

    ajax.onreadystatechange = function () {
        if (ajax.readyState == 4 && ajax.status == 200) {
            log('Project successfully migrated: ' + projectName + '.');
            log('---');
        } else if (ajax.status == 500) {
            log('ERROR! Could not migrate project: ' + projectName + '.');
            log('---');
        }
    };

    ajax.open('POST', '/api/projects/save?projectname='
            + encodeURIComponent(projectName)
            + '&username='
            + encodeURIComponent(username)
            + '&ispublic=false',
            true);

    ajax.send(rawProject);

};

function log (text) {
    importResultDiv.children[0].appendChild(document.createTextNode(text + '\n'));
};

function localize (text) {
    return text;
};
