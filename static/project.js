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
