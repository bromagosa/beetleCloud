function buildHyperlinks (text) {
	return text.replace(/(https?:\/\/[^\s,\(\)\[\]]+)/g,
		'<a href="$1" target="_blank">$1</a>');
}

$(document).ready(function(){
	$(".logo").css("transform","rotate(" + Math.random() * 360 + "deg)");
	//$(".icon-run").css("transform","rotate(" + Math.random() * 360 + "deg)");
	function rot_icon() {
		$(".icon-run").css("transform","rotate(" + Math.random() * 360 + "deg)");
		window.setTimeout( rot_icon, 3000 + Math.random() * 10000);
	}
	rot_icon();
});
