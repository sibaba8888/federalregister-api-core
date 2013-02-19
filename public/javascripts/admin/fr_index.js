/**
 *
 * @depend fr_index_popover_handler.js
 */


function highlight_el(event, el) {
  if( event.type === 'mouseleave' ) {
    el.removeClass('hover');
  } else {
    el.addClass('hover');
  }
}

/* fr_index_entry_popover is defined elsewhere we add 
 * the custom methods we need for this instance of it here,
 * Usually this is just the fields to be retrieved from the API 
 * and how to present the data returned. */
fr_index_popover_handler.fields = 'fields%5B%5D=toc_subject&fields%5B%5D=toc_doc&fields%5B%5D=document_number';
fr_index_popover_handler.add_popover_content = function() {
    var $tipsy_el = $('.tipsy'),
        prev_height = $tipsy_el.height(),
        fr_index_entry_popover_content_template = Handlebars.compile($("#fr-index-entry-popover-content-template").html()),
        popover_id = '#popover-' + this.current_el.data('document-number'),
        new_html = fr_index_entry_popover_content_template( this.popover_cache[this.current_el.data('document-number')] );

    $(popover_id).find('.loading').replaceWith( new_html );
  };


/* returns the current state of toc subject and doc titles as users make edits */
function current_toc_subjects() {
  return _.uniq($('.fr_index_subject').map(function() { return $(this).val(); }));
}
function current_toc_docs() {
  return _.uniq($('.fr_index_doc').map(function() { return $(this).val(); }));
}

/* using a function as the source for these typeaheads allows
 * them to stay up to date with changes on the page.
 * if just an array is provided that is cached and not updated */
function fr_index_toc_subject_typeahead(elements) {
  elements.find('.fr_index_subject').typeahead({
    minLength: 3,
    source: current_toc_subjects()
  });
}
function fr_index_toc_doc_typeahead(elements) {
  elements.find('.fr_index_doc').typeahead({
    minLength: 3,
    source: current_toc_docs()
  });
}

function highlightElement( element ) {
  element.scrollintoview({
    duration: 300,
    complete: function() {
      element.effect("highlight", {color: '#f5f8f9'}, 2000);
    }
  });
}

function hide_top_level_index_form(form) {
  form.hide();
  form.closest('li').removeClass('edit').find('a.cancel').first().removeClass('cancel').addClass('edit').html('Edit');
}

function initializeFrIndexEditor(elements) {
  var $elements = $(elements);

  $elements.find('a.wrapper').on('click', function(event) {
    event.preventDefault();
    $(this).siblings('ul.entry_details').toggle();
  });
  
  $elements.find('a.edit').on('click', function(event) {
    event.preventDefault();

    var link = $(this);
    var form = link.siblings('form').first();
    var top_level_form = null;
    if( ! form.hasClass('top_level') ) {
      top_level_form = link.closest('ul').
                            closest('li').
                            find('form.top_level').
                            first();
    }
    var el   = link.closest('li');
    

    if( form.css('display') === 'none' ) {
      if( top_level_form ) {
        hide_top_level_index_form(top_level_form);
      }

      link.removeClass('edit').addClass('cancel').html('Cancel');
      link.closest('li').addClass('edit');
      form.show();
      form.find('input[type!=hidden]').last().scrollintoview();
      form.find('input[type!=hidden]').first().focus();
      el.removeClass('hover');
    } else {
      link.removeClass('cancel').addClass('edit').html('Edit');
      form.hide();
      link.closest('li').removeClass('edit');
      el.addClass('hover');
    }
  });

  $elements.find('a.edit').on('hover', function(event) {
    var el = $(this).closest('li');
    if( event.type === 'mouseleave' ) {
      el.removeClass('hover');
    } else {
      el.addClass('hover');
    }
  });

  fr_index_toc_subject_typeahead($elements);
  fr_index_toc_doc_typeahead($elements);
  $elements.find('form').each(function(){
    var form = $(this);

      form.find('.fr_index_subject').each( function(event) {
        var $input = $(this);

        $input.tipsy({ opacity: 1.0,
                       gravity: 'e',
                       fallback: 'Category',
                       trigger: 'manual'});
      });

      form.find('.fr_index_doc').each( function(event) {
        var $input = $(this);

        $input.tipsy({ opacity: 1.0,
                       gravity: 'e',
                       fallback: 'Subject Line',
                       trigger: 'manual'});
      });


      form.find('.fr_index_subject, .fr_index_doc').on('focus', function(event) {
        var $input = $(this),
            tipsy_right_adjustment = $input.hasClass('fr_index_subject') ? 30 : 0;
        
        $input.tipsy('show');
        $('.tipsy').addClass('input_tipsy').css('left', $input.position().left - $('.tipsy').width() - tipsy_right_adjustment);
        $('.tipsy .tipsy-arrow').css('right', -16);
      });
      form.find('.fr_index_subject, .fr_index_doc').on('blur', function(event) {
        $(this).tipsy('hide');
      });

    form.unbind('submit').bind('submit', function(event) {
      var form = $(this);
      event.preventDefault();

      var submit_button = form.find('input[type=submit]').first();

      /* visually identify form as being saved */
      form.addClass('disabled');
      form.siblings('a.cancel').hide();
      submit_button.val('Saving');
      submit_button.attr("disabled", true);

      var path = form.attr('action');

      var data = form.serialize();
      $.ajax({
        url: path,
        data: data,
        type: 'PUT',
        dataType: 'json',
        success: function(response) {
          /* set form back to normal while it's still available */
          form.removeClass('disabled');
          form.siblings('a.cancel').show();
          submit_button.val('Save');
          submit_button.attr("disabled", false);
          form.find('input[type=text]').trigger('blur');

          var added_element;
          var wrapping_list = form.closest('ul.entry_type');

          var parent = form.closest('li');

          if (!parent.hasClass('top_level')) {
            var siblings = parent.siblings('li');

            if (siblings.size() === 0) {
              parent.closest('li.top_level').remove();
            }
            else if (siblings.size() === 1) {
              parent.closest('li.top_level').children('.edit').remove();
              parent.remove();
            }
          } else {
            parent.remove();
          }

          $('#' + response.id_to_remove).remove();

          var element_to_insert = response.element_to_insert;

          // insert alphabetically, immediately before of anything alphabetically after it
          wrapping_list.children('li').each(function() {
            var list_item = $(this);
            if (list_item.find('span.title:first').text() > response.header) {
              added_element = $(element_to_insert).insertBefore(list_item);
              return false;
            }
          });

          // if not already added ahead of an existing element, append it to the end
          if (!added_element) {
            added_element = $(element_to_insert).appendTo(wrapping_list);
          }

          highlightElement(added_element);
          initializeFrIndexEditor(added_element);
        }
      });
    });
  });
  return false;
}

$(document).ready(function() {

  initializeFrIndexEditor($('#content_area ul.entry_type > li'));

  var popover_handler = fr_index_popover_handler.initialize();
  if ( $("#fr-index-entry-popover-template") !== []) {
    var fr_index_entry_popover_template = Handlebars.compile($("#fr-index-entry-popover-template").html());
        
    $('body').delegate('.with_ajax_popover a.document_number', 'mouseenter', function(event) {
      var $el = $(this),
          $li = $el.closest('.with_ajax_popover');


      /* add tipsy to the element */
      $el.tipsy({ fade: true,
                  opacity: 1.0,
                  gravity: 'n',
                  offset: 5,
                  html: true,
                  title: function(){
                    return fr_index_entry_popover_template( {content: new Handlebars.SafeString('<div class="loading">Loading...</div>'),
                                                             document_number: $li.data('document-number'),
                                                             title: 'Original ToC Data'} );
                  } 
                });
      /* trigger the show or else it won't be shown until the next mouseover */
      $el.tipsy("show");
      $('.tipsy.tipsy-n').addClass('popover');

      /* get the ajax content and show it
       * this used to be bound to the li - so we pass it through here
       * to stay consistent with other uses of the handler */
      popover_handler.get_popover_content( $li );
    });
  }

  $('#indexes.admin form.max_date select#max_date').on('change', function(event) {
    $(this).closest('form').submit();
  });
});
