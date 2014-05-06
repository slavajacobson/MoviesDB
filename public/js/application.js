$(document).ready(function() {
	//ensure the server is up
	var scan_movies_sse = null;

	var app_live = new EventSource('/app_live');


	app_live.addEventListener('error', function(e) {
	  scan_movies_sse.close();
	  app_live.close();
	  $("script").remove();
	  $("html").html("<h1>Application was shutdown. Close this browser tab/window.</h1>");
	  

	}, false);



	$("#play_button").live("click", function(){

		$.post("/play", 
		{ 
		 	id: $(this).data("id")
		}).fail(function(){
			scan_movies_sse.close();
	  		app_live.close();

			alert("Error launching movie. Reopen application");
		});
	});




	$("#exit_app_button").click(function() {
		$.get('/exit', function(data) {

			$(html).empty();
		    
		});
	});
	$("#pause_sync_movies_button").click(function() {
		$.get('/pause_sync_movies', function(data) {

			scan_movies_sse.close();
		    
		});
	});

	$("#delete_broken_links_button").click(function() {
		$.get('/delete_broken_links', function(data) {

			alert("Cleared all broken links.");
		    
		});
	});

	$("#sync_movies_button").click(function() {

		scan_movies_sse = new EventSource('/scan_movies');
		
		scan_movies_sse.addEventListener('message', function(e) {
		  
			var data = JSON.parse(e.data);

			//console.log(data);

			if (data.completed == "true") {
				scan_movies_sse.close();
				//$("#sync_movies_progress .meter").css("width","100%");
				//$("form#filter_movies").find("[type='submit']").click();
			}

			$("#process_status").html(data.status_info);

			$("#process_percentage").html(data.percent_completed);
			$("#sync_movies_progress .meter").css("width",data.percent_completed + "%");
			$("#total_files_to_process").html(data.total);
			$("#current_process_file").html(data.file_number);
			$("#filename_processing").html(data.filename_info);

		}, false);
	});

	$("#clear_db").click(function() {

	
		$.post('/clear_db', $(this).serialize(), function(data) {
			$("form#filter_movies").find("[type='submit']").click();
			alert("All movies deleted!");
		    
		});


	});




	$("form#filter_movies").submit(function(e){
		e.preventDefault();
		$('#movies_library').empty();
		$("#spinner_wrapper").show();
		$.get('/filter', $(this).serialize(), function(data) {
			//$('#movies_library').quicksand( data, { adjustHeight: 'dynamic' } );
		    $('#movies_library').html(data);
		}).always(function() { $("#spinner_wrapper").hide(); });
	});

	$("form#settings").submit(function(e){
		e.preventDefault();

		$.post('/settings', $(this).serialize(), function(data) {
			alert("Saved!");
		    
		});
	});


	//load all movies
	//$("form#filter_movies").find("[type='submit']").click();

});