$.quickSignIn = {
  isHidden: function()  { return ($("#quick_signin").css('display') == 'none'); },
  isVisible: function() { return ($("#quick_signin").css('display') != 'none'); },

  setup: function() {
    var me = $("#cluetip").find("#quick_signin");

    // AJAX won't work w/out AUTH_TOKEN so redirect to regular signup page
    if(!AUTH_TOKEN) { 
      window.location = "/sessions/new";
      return false;
    }

    // Makes the form use AJAX
    me.submit(function(event){
      me.find('.signin_signup_button').click();
      return false; // the form submission will be handled through specific Form Element events
    });

    me.find('.signin_signup_button').click(function(event){
      me.find('.response_container').html('');
      if(!me.find('.sign_up:visible').length) { // if signup hasn't happened yet, just show full signup form
        $.post(me.attr('action'), me.serialize(), $.quickSignIn.signinSubmitCallback, 'json');
      } else {
        $.post(me.attr('action'), me.serialize(), $.quickSignIn.signupSubmitCallback, 'json');
      }
    });

    // Show the full signup form on clicking the 'Sign Up' button
    me.find('.signup_button').click(function(event){
      // if signup hasn't happened yet, just show full signup form
      if(!me.find('.sign_up:visible').length) $.quickSignIn.showSignUp();
      return false;
    });

    me.find('.signin_button').click(function(event){
      if(me.find('.sign_up:visible').length) { // if signup hasn't happened yet, just show full signup form
        $.quickSignIn.showSignIn();
      }
      return false;
    });

    // Handles clicking the X button to close the quick sign in box
    me.find('a.close').click(this.reset);

    // Keypress to handle pressing escape to close box.
    me.find('input').keydown(function(e){ if(e.keyCode == 27) $.quickSignIn.reset(); });

    $('input.login').focus();

    $.quickSignIn.showOverlay();

    return me;
  },

  signinSubmitCallback: function(resp){
    var me = $("#cluetip").find("#quick_signin");

    if(resp.success && me.attr('reloadPage') == 'false') { // success, no reload
      for(var a in resp) {
        console.log(resp[a]);
      }
      if(resp.profileLink) { $('#utility_nav').html(resp.profileLink); }
      $.quickSignIn.reset();

    } else if(resp.success && me.attr('reloadPage') != 'false') { // success reload
      window.location.reload();
    } else { // no success
      $.quickSignIn.updateResponse(resp.html);

      // Focus the correct input
      if(/Please type your password/.test(resp.html)) me.find('#quicksignin_password').focus();
      if(/Please type your email address/.test(resp.html)) {
        $.quickSignIn.showSignUp();
        me.find('#quicksignin_email').focus();
      }

      // attach event to 'Are you trying to Sign Up?' link
      me.find('.inline_signup_button').click($.quickSignIn.showSignUp);
    }
    return false;
  },

  signupSubmitCallback: function(resp){
    var me = $("#cluetip").find("#quick_signin");

    if(resp.success && me.attr('reloadPage') == 'false') { // success, no reload
      if(resp.profileLink) { $('.signup').removeClass('signup').addClass('user').html(resp.profileLink); }
      $.quickSignIn.updateResponse(resp.html);
    } else if(resp.success && me.attr('reloadPage') != 'false') { // success reload
      window.location.reload();
    } else { // no success
      $.quickSignIn.showSignUp();

      $.quickSignIn.updateResponse(resp.html);

      // Focus the correct input
      if(/Please type your email address/.test(resp.html)) me.find('#quicksignin_email').focus();
      if(/Please choose a password/.test(resp.html)) me.find('#quicksignin_password').focus();

      // attach event to 'Are you trying to Sign Up?' link
      me.find('.inline_signup_button').click($.quickSignIn.showSignUp);
    }

    return false;
  },

  reset: function() {
    var me = $("#cluetip").find("#quick_signin");
    me.find('.sign_up').hide();
    me.find('.controls').show();
    me.find('.controls_signup').hide();
    me.find('.signup_heading').text('Sign in to LimeCast');
    me.find('.signin_signup_button span').text('Sign in');
    me.attr('action', '/session');
    me.find('div.response_container').html('');
  },

  showSignUp: function(event) {
    me = $("#cluetip").find("#quick_signin");

    // Show default message if they click the inline signup link
    if(event && event.target.className=='inline_signup_button') me.find('div.response_container').html("<p>Choose your new user name.</p>");

    // Show signup form if hidden
    if(!me.find('.sign_up:visible').length) {
      me.find('.sign_up').show();
      me.find('.signup_heading').text('Sign up with LimeCast');
      me.find('.controls').hide();
      me.find('.controls_signup').show();
      me.find('.signin_signup_button span').text('Sign up');
      me.attr('action', '/users'); // Set the forms action to /users to call UsersController#create

      if(me.find('input.login').val().match(/[^ ]+@[^ ]+/)) {
        me.find('input.email').val(me.find('input.login').val());
        me.find('input.login').val("");
      }
    }
    me.find('input#user_login').focus();

    return false;
  },

  showSignIn: function(event) {
    var me = $("#cluetip").find("#quick_signin");

    // Show default message if they click the inline signup link
    if(event && event.target.className=='inline_signup_button') me.find('div.response_container').html("<p>Choose your new user name.</p>");

    // Show signup form if hidden
    if(me.find('.sign_up:visible').length) {
      me.find('.sign_up').hide();
      me.find('.signup_heading').text('Sign in to LimeCast');
      me.find('.controls').show();
      me.find('.controls_signup').hide();
      me.find('.signin_signup_button span').text('Sign in');
      me.attr('action', '/session'); // Set the forms action to /users to call UsersController#create
    }
    me.find('input.login').focus();

    return false;
  },

  // similar to jquery.dropdown.js
  showOverlay: function() {
    if($("#overlay").size() == 0) $('body').append("<div id=\"overlay\"></div>");
    $("#overlay").mousedown(function(){
      $('#cluetip-close').click();
      $(this).remove();
    }).css('height', $('body').attr('clientHeight')+'px');;
    $("#cluetip-close").click($.quickSignIn.reset);
  },

  // Updates the response section; if the response is the same as the current
  // response, it does a highlight effect on the current response.
  updateResponse: function(html) {
    var me = $("#cluetip").find("#quick_signin");
    resp_container = me.find('.response_container');
    if(html == resp_container.html()) resp_container.fadeOut().fadeIn();
    else resp_container.hide().html(html).fadeIn(150);
  }
}
