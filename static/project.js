function toggleLike () {
    var ajax = new XMLHttpRequest();
    ajax.onreadystatechange = function () {
        if (ajax.readyState == 4 && ajax.status == 200) {
            if ((JSON.parse(ajax.responseText)).text.match('unliked')) {
                document.getElementById('likes').children[0].classList.remove('liked');
                document.getElementById('likes').children[1].textContent =
                    Number(document.getElementById('likes').children[1].textContent) - 1;
            } else if ((JSON.parse(ajax.responseText)).text.match('liked')) {
                document.getElementById('likes').children[0].classList.add('liked');
                document.getElementById('likes').children[1].textContent =
                    Number(document.getElementById('likes').children[1].textContent) + 1;
            }
        }
    };
    ajax.open('GET', '/api' + window.location.pathname + '/like' , true);
    ajax.send(); 
};

function uploadImage (file) {
    var ajax = new XMLHttpRequest();

    ajax.open('POST', '/api' + window.location.pathname + '/altimage' , true);
    ajax.onreadystatechange = function() {
        if (ajax.readyState == 4 && ajax.status == 200) {
            setAlternateImageSrc();
            featureImage(true);
        }
    };

    resizeAndCrop(
            file,
            function (resizedImage) {
                ajax.send(resizedImage);
            });
};

function featureImage (doFeatureIt) {
    var ajax = new XMLHttpRequest();
    ajax.onreadystatechange = function () {
        if (ajax.readyState == 4 && ajax.status == 200) {
            toggleFeaturedClass();
            sortThumbnails();
        }
    };
    ajax.open('GET', '/api' + window.location.pathname + '/altimage?featureImage=' + doFeatureIt , true);
    ajax.send(); 
};

function toggleFeaturedClass () {
    var thumbs = document.getElementById('thumbs');
    if (thumbs.children[0].classList.contains('featured')) {
        thumbs.children[0].classList.remove('featured');
        thumbs.children[1].classList.add('featured');
    } else {
        thumbs.children[0].classList.add('featured');
        thumbs.children[1].classList.remove('featured');
    }
};

function sortThumbnails () {
    var thumbs = document.getElementById('thumbs');
    if (thumbs.children[1].classList.contains('featured')) {
        thumbs.appendChild(thumbs.children[0]);
    }
};

function setAlternateImageSrc () {
    var ajax = new XMLHttpRequest();
    ajax.onreadystatechange = function () {
        if (ajax.readyState == 4 && ajax.status == 200) {
            document.getElementsByClassName('alternate')[0].src = ajax.responseText;
        }
    };
    ajax.open('GET', '/api' + window.location.pathname + '/altimage', true);
    ajax.send(); 
};

function resizeAndCrop (imageFile, callback) {
    var img = document.createElement('img'),
        reader = new FileReader(),
        canvas = document.createElement('canvas'),
        ctx = canvas.getContext('2d'),
        largerCoord;

    canvas.width = 480;
    canvas.height = 360;

    reader.onload = function (event) { img.src = event.target.result; };
    reader.readAsDataURL(imageFile);
    
    img.onload = function () {
        drawImageProp(ctx, img);
        callback(canvas.toDataURL('image/png'));
    };
};

function drawImageProp (ctx, img) {
    // By Ken Fyrstenberg Nilsen
    // http://jsfiddle.net/epistemex/yqce3tuw/1/
    var x = 0,
        y = 0,
        w = ctx.canvas.width,
        h = ctx.canvas.height,
        offsetX = 0.5,
        offsetY = 0.5,
        iw = img.width,
        ih = img.height,
        r = Math.min(w / iw, h / ih),
        nw = iw * r,
        nh = ih * r,
        cx, cy, cw, ch, ar = 1;

    if (nw < w) ar = w / nw;                             
    if (Math.abs(ar - 1) < 1e-14 && nh < h) ar = h / nh;

    nw *= ar;
    nh *= ar;
    cw = iw / (nw / w);
    ch = ih / (nh / h);
    cx = (iw - cw) * offsetX;
    cy = (ih - ch) * offsetY;

    if (cx < 0) cx = 0;
    if (cy < 0) cy = 0;
    if (cw > iw) cw = iw;
    if (ch > ih) ch = ih;

    ctx.drawImage(img, cx, cy, cw, ch,  x, y, w, h);
};

setAlternateImageSrc();
sortThumbnails();

document.getElementsByClassName('notes')[0].innerHTML = (buildHyperlinks(document.getElementsByClassName('notes')[0].innerHTML));



function getComments (username, projectname) {
    ajax.onreadystatechange = function () {
        if (ajax.readyState == 4 && ajax.status == 200) {
            comments =JSON.parse(ajax.responseText);
            updateComments();
        }
    };
    path = '/api/users/'+ username + '/projects/' + projectname +'/comments';
    ajax.open('GET', path, true);
    ajax.send();
}

function getComment (id) {
    ajax.onreadystatechange = function () {
        if (ajax.readyState == 4 && ajax.status == 200) {
            comment =JSON.parse(ajax.responseText);
            addComment(comment[0],true);
        }
    };
    path = '/api/comment/' + id;
    ajax.open('GET', path, true);
    ajax.send();
}

function addComment(comment, prepend) {
    comment_div = document.getElementById('comment-pool');
    div = document.createElement('div');
    div.setAttribute("id", "comment-" + comment.id);

    if (!prepend)
        comment_div.appendChild(div);
    else {
        comment_div.insertBefore(div, comment_div.firstChild);
    }

    div.innerHTML = "";

    if ( comment.author == username || isadmin) {// if owner
        div.innerHTML += '<div style="float:right"><a class=\"pure-button red-button\" role=\"button\" onclick=\"delete_comment('+
            comment.id +' )\">Delete</a></div>';
    }
    div.innerHTML += '<div class="comment-item">' +
        '<div class="pure-g"><div class="pure-u-1-5">' +
        '<img width="48" height="48" class="gravatar" alt=""' +
        ' src="http://www.gravatar.com/avatar/' + comment.gravatar + '?s=48&d=http%3A%2F%2Fbeta.turtlestitch.org%2Fstatic%2Flogo.png" />' +
        '</div><div class="pure-u-4-5">' +
        '<span class="author"><a href="/users/' +
        comment.author + '">' + encodeURIComponent(comment.author) +
        '</a></span><br /><p>' +
        buildHyperlinks(comment.contents) + '</p>' +
        '<span class="date">' +
        moment(comment.date).fromNow() +
        '</span><br />' +
        '</ div>' +
        '</ div><div class="clear"></div></div>';


   //div.classList.add('flash');
}

function updateComments () {
    if (comments.length) {
        comments.forEach(
            function (comment) {
                addComment(comment, false);
            }
        );
    }
}

function post_comment (projectname, author, username) {
    var ajax_save_comment = new XMLHttpRequest();
    ajax_save_comment.onreadystatechange = function () {
        if (ajax_save_comment.readyState == 4 && ajax_save_comment.status == 200) {
            document.getElementById('new_comment').value = "";
            comments = JSON.parse(ajax_save_comment.responseText);
            getComment(comments.comment.id);
            document.getElementById('comments-count').innerHTML= parseInt(document.getElementById('comments-count').innerHTML) + 1;
        }
    };
    ajax_save_comment.open('POST', '/api/comments/new', true);
    ajax_save_comment.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
    ajax_save_comment.send("projectname=" +
        encodeURIComponent(projectname) +
        "&author=" +
        encodeURIComponent(author) +
        "&projectowner=" +
        encodeURIComponent(username) +
        "&contents=" +
        encodeURIComponent(document.getElementById('new_comment').value)
        );
      document.getElementById('new_comment').classList.add('flash');
}

function delete_comment (id) {
    message = 'You are about to delete this comment. <br /><br />' +
            'Are you sure you want to continue?';
    callback = function (result) {
        if (!result) return;
        var ajax = new XMLHttpRequest();
        ajax.onreadystatechange = function () {
            if (ajax.readyState == 4 && ajax.status == 200) {
                ret = JSON.parse(ajax.responseText);
                document.getElementById('comment-' + id).parentNode.removeChild(document.getElementById('comment-' + id));
                document.getElementById('comments-count').innerHTML=parseInt(document.getElementById('comments-count').innerHTML) -1;
            }
        };
        ajax.open('GET', '/api/comment/delete/' + id, true);
        ajax.send();
    };
    
	confirm(message, function() {callback(true)}, function() {return});
}

function reset_comment () {
    document.getElementById('new_comment').value = '';
}
