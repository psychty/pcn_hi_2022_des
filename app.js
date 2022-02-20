// Footprint of PCNs

//  Load pcn_boundary geojson file
var PCN_geojson = $.ajax({
  url: "./outputs/pcn_boundary_simple.geojson",
  dataType: "json",
  success: console.log("PCN boundary data successfully loaded."),
  error: function (xhr) {
    alert(xhr.statusText);
  },
});

// Load PCN level data
 $.ajax({
  url: "./outputs/PCN_data.json",
  dataType: "json",
  async: false,
  success: function(data) {
    PCN_data = data;
   console.log('PCN data successfully loaded.')},
  error: function (xhr) {
    alert('PCN data not loaded - ' + xhr.statusText);
  },
});

// Load PCN pyramid data
$.ajax({
  url: "./outputs/PCN_pyramid_data.json",
  dataType: "json",
  async: false,
  success: function(data) {
    PCN_pyramid_data = data;
   console.log('PCN pyramid data successfully loaded.')},
  error: function (xhr) {
    alert('PCN pyramid data not loaded - ' + xhr.statusText);
  },
});

var width = window.innerWidth * 0.8 - 20;
// var width = document.getElementById("daily_case_bars").offsetWidth;
if (width > 900) {
  var width = 900;
}
var width_margin = width * 0.15;

var height = window.innerHeight * .5;


// Get a list of unique PCN_codes from the data using d3.map
var pcn_codes = d3
  .map(PCN_data, function (d) {
    return d.PCN_Code;
  })
  .keys();

// Get a list of unique PCN_names from the data using d3.map
var pcn_names = d3
  .map(PCN_data, function (d) {
    return d.PCN_Name;
  })
  .keys();

// Create an array of colours
pcn_colours = ['#a04866', '#d74356', '#c4705e', '#ca572a', '#d49445',  '#526dd6', '#37835c', '#a2b068', '#498a36',  '#a678e4', '#8944b3',  '#57c39b', '#4ab8d2', '#658dce', '#776e29', '#60bf52', '#7e5b9e' ,  '#afb136',  '#ce5cc6','#d58ec6']

// Create a function which takes the pcn_code as input and outputs the colour
var setPCNcolour = d3
  .scaleOrdinal()
  .domain(pcn_codes)
  .range(pcn_colours);

// Create a list with an item for each PCN and display the colour in the border 
pcn_codes.forEach(function (item, index) {
  var list = document.createElement("li");
  list.innerHTML = item + ' ' + pcn_names[index];
  list.className = "key_list";
  list.style.borderColor = setPCNcolour(index);
  var tt = document.createElement("div");
  tt.style.borderColor = setPCNcolour(index);
  var tt_h3_1 = document.createElement("h3");
  tt_h3_1.innerHTML = item;
  tt.appendChild(tt_h3_1);
  var div = document.getElementById("pcn_key");
  div.appendChild(list);
});

// Create a function to add stylings to the polygons in the leaflet map
function pcn_boundary_colour(feature) {
  return {
    fillColor: setPCNcolour(feature.properties.PCN_code),
    color: setPCNcolour(feature.properties.PCN_code),
    weight: 1,
    fillOpacity: 0.85,
  };
}

// Define the background tiles for our maps 
var tileUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";

// Define an attribution statement to go onto our maps
var attribution =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Contains Ordnance Survey data © Crown copyright and database right 2022';

// Specify that this code should run once the PCN_geojson data request is complete
$.when(PCN_geojson).done(function () {

// Create a leaflet map (L.map) in the element map_1_id
var map_1 = L.map("map_1_id");
 
// add the background and attribution to the map
L.tileLayer(tileUrl, { attribution })
 .addTo(map_1);
  
var pcn_boundary = L.geoJSON(PCN_geojson.responseJSON, { style: pcn_boundary_colour })
 .addTo(map_1)
 .bindPopup(function (layer) {
    return (
      "Primary Care Network: <Strong>" +
      layer.feature.properties.PCN_code +
      " " +
      layer.feature.properties.PCN_name +
      "</Strong>"
    );
 });

 map_1.fitBounds(pcn_boundary.getBounds());
});


// ! Population pyramid

var formatPercent = d3.format(".0%"),
    margin_middle = 80,
    pyramid_plot_width = (height/2) - (margin_middle/2),
    male_zero = pyramid_plot_width,
    female_zero = pyramid_plot_width + margin_middle;

console.log(pyramid_plot_width, height, height + (margin_middle/2))

// append the svg object to the body of the page
var svg_pcn_pyramid = d3.select("#pyramid_pcn_datavis")
.append("svg")
.attr("width", height + (margin_middle/2))
.attr("height", height + (margin_middle/2))
.append("g")

// We need to create a dropdown button for the user to choose which area to be displayed on the figure.
d3.select("#select_pcn_pyramid_button")
  .selectAll("myOptions")
  .data(pcn_names)
  .enter()
  .append("option")
  .text(function (d) {
    return d;
  })
  .attr("value", function (d) {
    return d;
  });

// Retrieve the selected area name
var chosen_pcn_pyramid_area = d3
  .select("#select_pcn_pyramid_button")
  .property("value");

// Use the value from chosen_pcn_pyramid_area to populate a title for the figure. This will be placed as the element 'selected_pcn_pyramid_title' on the webpage
d3.select("#selected_pcn_pyramid_title").html(function (d) {
  return (
    "Population pyramid; " +
    chosen_pcn_pyramid_area +
    "; registered population"   
   );
 });

 var age_levels = ["0-4 years", "5-9 years", "10-14 years", "15-19 years", "20-24 years", "25-29 years", "30-34 years", "35-39 years", "40-44 years", "45-49 years", "50-54 years", "55-59 years", "60-64 years", "65-69 years", "70-74 years", "75-79 years", "80-84 years", "85-89 years", "90-94 years", '95+ years']

PCN_pyramid_data.sort(function(a,b) {
  return age_levels.indexOf(a.Age_group) > age_levels.indexOf(b.Age_group)});

wsx_pcn_pyramid_data = PCN_pyramid_data.filter(function(d,i){
  return d.Area_name === 'NHS West Sussex CCG' })

// Filter to get out chosen dataset
chosen_pcn_pyramid_data = PCN_pyramid_data.filter(function(d,i){
  return d.Area_name === chosen_pcn_pyramid_area })

chosen_pcn_pyramid_summary_data = PCN_data.filter(function(d,i){
    return d.PCN_Name === chosen_pcn_pyramid_area }) 
 
d3.select("#pcn_age_structure_text_1").html(function (d) {
  return (
   "There are estimated to be <b>" +
   d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['Total']) +
   ' </b>patients regisered to ' +
   chosen_pcn_pyramid_summary_data[0]['Practices'] +
   ' partnering practices in ' +
   chosen_pcn_pyramid_area + 
  ' as at January 2022.'   
  );
});

d3.select("#pcn_age_structure_text_2").html(function (d) {
  return (
  '<b>' +
  d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['65+ years']) +
  ' </b>patients are aged 65+ and over, this is ' +
  d3.format('.1%')(chosen_pcn_pyramid_summary_data[0]['65+ years'] / chosen_pcn_pyramid_summary_data[0]['Total'])
  );
});

d3.select("#pcn_age_structure_text_3").html(function (d) {
 return (
  '<b>' +
  d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['0-15 years']) +
  '</b> are aged 0-15 and <b>'+
  d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['16-64 years']) +
  '</b> are aged 16-64.'
 );
 });

// find the maximum data value on either side
 var maxPopulation_static_pyr = Math.max(
  d3.max(chosen_pcn_pyramid_data, function(d) { return d['Proportion']; }),
  d3.max(wsx_pcn_pyramid_data, function(d) { return d['Proportion']; })
);

// the scale goes from 0 to the width of the pyramid plotting region. We will invert this for the left x-axis
var x_static_pyramid_scale_male = d3.scaleLinear()
 .domain([0, maxPopulation_static_pyr])
 .range([male_zero, (0 + margin_middle/4)])
//  .nice();

var xAxis_static_pyramid = svg_pcn_pyramid
 .append("g")
 .attr("transform", "translate(0," + height + ")")
 .call(d3.axisBottom(x_static_pyramid_scale_male).tickFormat(formatPercent));

var x_static_pyramid_scale_female = d3.scaleLinear()
 .domain([0, maxPopulation_static_pyr])
 .range([female_zero, (height - margin_middle/4)])
//  .nice();

var xAxis_static_pyramid_2 = svg_pcn_pyramid
 .append("g")
 .attr("transform", "translate(0," + height + ")")
 .call(d3.axisBottom(x_static_pyramid_scale_female).tickFormat(formatPercent));

 var wsx_pyramid_scale_bars = d3.scaleLinear()
 .domain([0, maxPopulation_static_pyr])
 .range([0, (pyramid_plot_width - margin_middle/4)]);

var y_pyramid_wsx = d3.scaleBand()
 .domain(age_levels)
 .range([height, 0])
 .padding([0.2]);

 var yaxis_pos = height/2
 
 var yAxis_static_pyramid = svg_pcn_pyramid
 .append("g")
 .attr("transform", "translate(0" + yaxis_pos + ",0)")
 .call(d3.axisLeft(y_pyramid_wsx).tickSize(0))
 .style('text-anchor', 'middle')
 .select(".domain").remove()
 
svg_pcn_pyramid
   .selectAll("myRect")
   .data(chosen_pcn_pyramid_data)
   .enter()
   .append("rect")
   .attr("class", "pyramid_1")
   .attr("x", female_zero)
   .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
   .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Proportion']); })
   .attr("height", y_pyramid_wsx.bandwidth())
   .attr("fill", "#0099ff")
 
svg_pcn_pyramid
  .selectAll("myRect")
  .data(chosen_pcn_pyramid_data)
  .enter()
  .append("rect")
  .attr("class", "pyramid_1")
  .attr("x", function(d) { return male_zero - wsx_pyramid_scale_bars(d['Proportion']); })
  .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
  .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Proportion']); })
  .attr("height", y_pyramid_wsx.bandwidth())
  .attr("fill", "#ff6600")
   
 // TODO fix lines 
// svg_pcn_pyramid
// .append('g')
// .append("path")
// .datum(wsx_pcn_pyramid_data)
// .attr("d", d3.line()
// .x(function (d) { return wsx_pyramid_scale_bars(d['Proportion']) + female_zero })
// .y(function(d) { return y_pyramid_wsx(d.Age_group) + 10; }))
// .attr("stroke", '#005b99')
// .style("stroke-width", 3)
// .style("fill", "none");

// The .on('change) part says when the drop down menu (select element) changes then retrieve the new selected area name and then use it to update the selected_pcn_pyramid_title element 
d3.select("#select_pcn_pyramid_button").on("change", function (d) {
  var chosen_pcn_pyramid_area = d3
    .select("#select_pcn_pyramid_button")
    .property("value");
   
  d3.select("#selected_pcn_pyramid_title").html(function (d) {
    return (
       "Population pyramid; " +
        chosen_pcn_pyramid_area +
        "; registered population"   
      );
    });

    chosen_pcn_pyramid_data = PCN_pyramid_data.filter(function(d,i){
      return d.Area_name === chosen_pcn_pyramid_area })
    
    chosen_pcn_pyramid_summary_data = PCN_data.filter(function(d,i){
        return d.PCN_Name === chosen_pcn_pyramid_area }) 
    
    d3.select("#pcn_age_structure_text_1").html(function (d) {
      return (
       "There are estimated to be <b>" +
        d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['Total']) +
        ' </b>patients regisered to ' +
        chosen_pcn_pyramid_summary_data[0]['Practices'] +
         ' partnering practices in ' +
        chosen_pcn_pyramid_area + 
        ' as at January 2022.'   
       );
     });
    
    d3.select("#pcn_age_structure_text_2").html(function (d) {
     return (
       '<b>' +
      d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['65+ years']) +
      ' </b>patients are aged 65+ and over, this is ' +
      d3.format('.1%')(chosen_pcn_pyramid_summary_data[0]['65+ years'] / chosen_pcn_pyramid_summary_data[0]['Total'])
      );
    });
    
    d3.select("#pcn_age_structure_text_3").html(function (d) {
      return (
        '<b>' +
       d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['0-15 years']) +
       '</b> are aged 0-15 and <b>'+
       d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['16-64 years']) +
       '</b> are aged 16-64.'
       );
      });

  svg_pcn_pyramid.selectAll(".pyramid_1").remove();

  var maxPopulation_static_pyr = Math.max(
    d3.max(chosen_pcn_pyramid_data, function(d) { return d['Proportion']; }),
    d3.max(wsx_pcn_pyramid_data, function(d) { return d['Proportion']; })
  );
  
x_static_pyramid_scale_male
  .domain([0, maxPopulation_static_pyr])
  
x_static_pyramid_scale_female 
  .domain([0, maxPopulation_static_pyr])
  
wsx_pyramid_scale_bars 
  .domain([0,maxPopulation_static_pyr])

  svg_pcn_pyramid
   .selectAll("myRect")
   .data(chosen_pcn_pyramid_data)
   .enter()
   .append("rect")
   .attr("class", "pyramid_1")
   .attr("x", female_zero)
   .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
   .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Proportion']); })
   .attr("height", y_pyramid_wsx.bandwidth())
   .attr("fill", "#0099ff")
 
svg_pcn_pyramid
  .selectAll("myRect")
  .data(chosen_pcn_pyramid_data)
  .enter()
  .append("rect")
  .attr("class", "pyramid_1")
  .attr("x", function(d) { return male_zero - wsx_pyramid_scale_bars(d['Proportion']); })
  .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
  .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Proportion']); })
  .attr("height", y_pyramid_wsx.bandwidth())
  .attr("fill", "#ff6600")

});


