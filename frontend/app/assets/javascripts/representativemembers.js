$(function() {

  function handleRepresentativeChange($subform, isRepresentative) {
    if(isRepresentative) {
      $subform.addClass("is-representative");
    } else {
      $subform.removeClass("is-representative");
    }

    $(":input[name$=\"[is_representative]\"]", $subform).val(isRepresentative ? 1 : 0);

    $subform.trigger("formchanged.aspace");
  };

  $(document).bind("subrecordcreated.aspace", function (event, object_name, subform) {
    if (object_name === "file_version" || object_name === 'instance') {
      var $subform = $(subform);
      var $section = $subform.closest("section.subrecord-form");
      var isRepresentative = $(":input[name$=\"[is_representative]\"]", $subform).val() === '1';

      var eventName = "newrepresentative" + object_name.replace(/_/, '') + ".aspace";

      if (isRepresentative) {
        $subform.addClass("is-representative");
      }

      $(".is-representative-toggle", $subform).click(function (e) {
        e.preventDefault();

        $section.triggerHandler(eventName, [$(e.currentTarget).is('.cancel-representative') ? false : $subform])
      });

      $section.on(eventName, function (e, representative_subform) {
        handleRepresentativeChange($subform, representative_subform == $subform)
      });

    }
  });


  function toggleThumbnail($subform, toggleOnOrOff) {
    if (toggleOnOrOff === 'off') {
      $subform.removeClass('is-thumbnail');
      $subform.find(':hidden[name$="[is_display_thumbnail]"]').val(0);
    } else {
      $subform.addClass('is-thumbnail');
      $subform.find(':hidden[name$="[is_display_thumbnail]"]').val(1);
    }
  }

  $(document).bind("subrecordcreated.aspace", function (event, object_name, subform) {
    if (object_name === "file_version") {
      const  $subform = $(subform);
      const  $section = $subform.closest("section.subrecord-form");

      if ($subform.find(':hidden[name$="[is_display_thumbnail]"]').val() === '1') {
        $subform.addClass('is-thumbnail');
      }

      $subform.on('click', '.is-thumbnail-toggle', function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();

        toggleThumbnail($section.find('.is-thumbnail'), 'off');
        toggleThumbnail($subform, 'on');
      });

      $subform.on('click', '.cancel-thumbnail', function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();

        toggleThumbnail($subform, 'off');
      });
    }
  });

});
