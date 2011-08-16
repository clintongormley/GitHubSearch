var timeline,timeline_data, repo, issues_form,loader,state_counts, submitting;

$(function(){
    issues_form = $('#issues_search');
    init_form();
    init_user_autocomplete();
    init_user_popup();
    init_issue_view();

    loader = $('<div id="loader">').appendTo('body').hide();

    render_chart(timeline_data);

});

function render_chart(data) {
    if (data.length === 0 ) {
        return;
    }
    if (data.length === 1) {
        var now = new Date();
        data.push([now.getTime(),0])
    }

    timeline = new Highcharts.Chart({
        chart: {
            animation: false,
            renderTo: 'timeline',
            alignTicks: false,
            zoomType: "x",
            events: {
                click: function(e) {
                    if (submitting) { return};
                    $('#min_date').val('');
                    $('#max_date').val('');
                    issues_form.trigger('submit');
                },
                selection: function(e) {
                    e.preventDefault();
                    var min = '',max = '';
                    if (e.xAxis) {
                        min = Math.round(e.xAxis[0].min);
                        max = Math.round(e.xAxis[0].max);
                    }
                    $('#min_date').val(min);
                    $('#max_date').val(max);
                    submitting = true;
                    issues_form.trigger('submit');
                    return true;
                }
            }
        },
        credits:        { enabled: false },
        navigator:      { enabled: false },
        rangeSelector:  { enabled: false },
        scrollbar:      { enabled: false },
        title:          { text: null },
        legend:         { enabled: false },
        plotOptions:    {
            column:     {
                borderWidth: 0,
                pointWidth: 4,
                shadow: false,
                color: '#10047B',
                events: {
                    click: function(e) {
                        var min = '',max = '';
                        if (e.point) {
                            min = e.point.config[0];
                            min = min - 1000 * 7 * 24 * 3600;
                            max = min + 1000 * 14 * 24 * 3600;
                        }
                        $('#min_date').val(min);
                        $('#max_date').val(max);
                        issues_form.trigger('submit');
                    }
                 }
        }},
        xAxis: {
            type: 'datetime',
            maxZoom: 14 * 24 * 3600000,
            title: { text: null },
            dateTimeLabelFormats: {
                second: '%e. %b %y',
                minute: '%e. %b %y',
                hour: '%e. %b %y',
                day: '%e. %b %y',
                week: '%e. %b %y',
                month: '%b %y',
                year: '%Y'
            }
        },
        yAxis: {
            title: { text: null}
        },
        series: [{
            name: 'Issues',
            type: 'column',
            data: data
        }]
    });
};

function init_form() {
    var current_search = 0;
    var last_search;

    issues_form.submit(function(e){
        e.preventDefault();

        var search_id = ++current_search;

        var do_search = function () {
            if (search_id !== current_search) { return; }
            if ($('#user').val() === '') {
                $('#user_id').val('');
            }
            var params = issues_form.serializeArray();
            $('#labels li.selected .label_name').each(function() {
                params.push({"name": "label", "value": $(this).text().trim()});
            });
            var this_search = $.param(params);
            if (this_search === last_search) { return }
            $('#issues_list').fadeTo(0,0.5);
            $.get(issues_form.attr('action'),params,function(data) {
                submitting = false;
                if (search_id !== current_search) { return; }
                last_search = this_search;
                render_results(data);
                $('#issues_list').fadeTo(0,1);
            });
        };
        window.setTimeout(do_search,25);

    });
    issues_form.find('#keywords').keyup(function(e) {
        if (e.which !== 32) {
            issues_form.trigger('submit');
        }
    });
    issues_form.find('input:radio').click(function(e) {
        issues_form.trigger('submit');
    });
    issues_form.find('select').change(function(e) {
        issues_form.trigger('submit');
    });

}

function render_results(data) {
    loader.html(data);

    var selected = state_counts.selected;
    delete state_counts.selected;

    $.each(state_counts,function(k,v) {
        var label = $('#state_count label[for="state_' + k + '"]');
        label.html(v);
        if (k === selected) {
            label.addClass('selected');
        } else {
            label.removeClass('selected');
        }
     });

     $('#issues_list .issues > li').remove();
     $('#issues_list .issues').append(loader.find('.issues > li'));

    timeline.series[0].setData(timeline_data);
    var x = timeline.xAxis[0];
    x.removePlotBand('window');
    var min = $('#min_date').val();
    var max = $('#max_date').val();
    if (min) {
        x.addPlotBand({
            id: "window",
            from: min,
            to: max,
            color: "#d0dbe8"
        })
    }

}

function init_user_autocomplete() {
    $('#user').focus(function(){ $(this).css('color','');})
    .blur( function() {
        var submit=false;
        if ($('#user_id').val() && ! $('#user').val()) {
            $('#user_id').val('');
            submit = true;
        }
        if ($('#user_id').val() === '') {
            $(this).css('color','#ccc');
        }
        if (submit) {
            issues_form.trigger('submit');
        }
    });

    $( "#user" ).autocomplete({
        source: "/" + repo + "/users",
        minLength: 0,
        focus: function( event, ui ) {
            $( "#user" ).val( ui.item.label );
            return false;
        },
        select: function( event, ui ) {
            $( "#user" ).val( ui.item.label );
            $( "#user_id" ).val( ui.item.id );
            issues_form.trigger('submit');
            return false;
        },
        change: function( event, ui ) {
            if (!ui.item) {
                $("#user").css('color','#ccc');
                $("#user_id").val('');
                issues_form.trigger('submit');
            };
        }

    });

}
function init_user_popup() {
    $(".user").live('hover',function(){
        $(this).find('.popup').fadeToggle();
    });
}

function init_issue_view() {
    $("a.issue_link, .num_comments").live('click', function(e) {
        e.preventDefault();
        var p = $(this).parents('div.issue');
        p.find('.snippet, .full').slideToggle();
    });
}
