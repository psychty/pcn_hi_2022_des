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

// Load GP and PCN deprivation data
$.ajax({
  url: "./outputs/PCN_deprivation_data.json",
  dataType: "json",
  async: false,
  success: function(data) {
    GP_PCN_deprivation_data = data;
   console.log('PCN deprivation data successfully loaded.')},
  error: function (xhr) {
    alert('PCN deprivation data not loaded - ' + xhr.statusText);
  },
});

GP_location = GP_PCN_deprivation_data.filter(function(d,i){
  return d.Type === 'GP'})

// Add a new field which is the proportion in the most deprived quintile
GP_location.forEach(function(d) {
  d.Proportion_most = +d['20% most deprived'] / +d['Total'],
  d.Proportion_q2 = +d['Quintile 2'] / +d['Total'],
  d.Proportion_q3 = +d['Quintile 3'] / +d['Total'],
  d.Proportion_q4 = +d['Quintile 4'] / +d['Total'],
  d.Proportion_least = +d['20% least deprived'] / +d['Total']
});

GP_location.sort(function(a,b) { return +b.Proportion_most - +a.Proportion_most })

PCN_deprivation_data = GP_PCN_deprivation_data.filter(function(d,i){
  return d.Type === 'PCN'})

// Add a new field which is the proportion in the most deprived quintile
PCN_deprivation_data.forEach(function(d) {
  d.Proportion_most = +d['20% most deprived'] / +d['Total'],
  d.Proportion_q2 = +d['Quintile 2'] / +d['Total'],
  d.Proportion_q3 = +d['Quintile 3'] / +d['Total'],
  d.Proportion_q4 = +d['Quintile 4'] / +d['Total'],
  d.Proportion_least = +d['20% least deprived'] / +d['Total']
});

PCN_deprivation_data.sort(function(a,b) { return +b.Proportion_most - +a.Proportion_most })
// We could have done this in R and read in a wider table, but this approach keeps the file size load as small as possible as calculations can be done by the browser.

// Load LSOA deprivation geojson
var Deprivation_geojson = $.ajax({
  url: "./outputs/lsoa_deprivation_2019_west_sussex.geojson",
  dataType: "json",
  success: console.log("LSOA deprivation data successfully loaded."),
  error: function (xhr) {
    alert(xhr.statusText);
  },
});

// Load MSOA inequalities geojson
var msoa_geojson = $.ajax({
  url: "./outputs/msoa_inequalities.geojson",
  dataType: "json",
  success: console.log("MSOA data successfully loaded."),
  error: function (xhr) {
    alert(xhr.statusText);
  },
});

window.onload = () => {
  loadTable_pcn_numbers_in_quintiles(PCN_deprivation_data);
  loadTable_gp_numbers_in_quintiles(chosen_PCN_gp_quintile);
};

wsx_areas = ['Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing']

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
    fillColor: setPCNcolour(feature.properties.PCN_Code),
    color: setPCNcolour(feature.properties.PCN_Code),
    weight: 1,
    fillOpacity: 0.85,
  };
}

// Create a function to add stylings to the polygons in the leaflet map
function pcn_boundary_overlay_colour(feature) {
  return {
    fillColor: 'none',
    color: setPCNcolour(feature.properties.PCN_Code),
    weight: 2,
    fillOpacity: 0.85,
  };
}

var deprivation_deciles = [
  "10% most deprived",
  "Decile 2",
  "Decile 3",
  "Decile 4",
  "Decile 5",
  "Decile 6",
  "Decile 7",
  "Decile 8",
  "Decile 9",
  "10% least deprived",
];

var deprivation_colours = [
  "#0000FF",
  "#2080FF",
  "#40E0FF",
  "#70FFD0",
  "#90FFB0",
  "#C0E1B0",
  "#E0FFA0",
  "#E0FF70",
  "#F0FF30",
  "#FFFF00",
];

var lsoa_covid_imd_colour_func = d3
  .scaleOrdinal()
  .domain(deprivation_deciles)
  .range(deprivation_colours);

// // Create a list with an item for each PCN and display the colour in the border 
// deprivation_deciles.forEach(function (item, index) {
//   var list = document.createElement("li");
//   list.innerHTML = item;
//   list.className = "key_list";
//   list.style.borderColor = lsoa_covid_imd_colour_func(index);
//   var tt = document.createElement("div");
//   tt.style.borderColor = setPCNcolour(index);
//   var tt_h3_1 = document.createElement("h3");
//   tt_h3_1.innerHTML = item;
//   tt.appendChild(tt_h3_1);
//   var div = document.getElementById("deprivation_key");
//   div.appendChild(list);
// });

function lsoa_deprivation_colour(feature) {
  return {
    fillColor: lsoa_covid_imd_colour_func(feature.properties.IMD_2019_decile),
    color: lsoa_covid_imd_colour_func(feature.properties.IMD_2019_decile),
    // color: 'blue',
    weight: 1,
    fillOpacity: 0.85
  }
}

function core20_deprivation_colour(feature) {
  return {
    fillColor: 'red',
    color: 'red',
    weight: 2,
    fillOpacity: 0.25
  }
}

// Define the background tiles for our maps 
// This tile layer is coloured
// var tileUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";

// This tile layer is black and white
var tileUrl = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png";
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
      layer.feature.properties.PCN_Code +
      " " +
      layer.feature.properties.PCN_Name +
      "</Strong>"
    );
 });

map_1.fitBounds(pcn_boundary.getBounds());

// TODO fix gp markers
// This loops through the dataframe and plots a marker for every record.

var pane1 = map_1.createPane('markers1');

 for (var i = 0; i < GP_location.length; i++) {
 gps = new L.circleMarker([GP_location[i]['lat'], GP_location[i]['long']],
      {
      pane: 'markers1',
      radius: 6,
      color: '#000',
      weight: .5,
      fillColor: setPCNcolour(GP_location[i]['PCN_Code']),
      fillOpacity: 1})
    .bindPopup('<Strong>' + GP_location[i]['Area_Code'] + ' ' + GP_location[i]['Area_Name'] + '</Strong><br><br>This practice is part of the ' + GP_location[i]['PCN_Code'] + ' ' + GP_location[i]['PCN_Name'] + '. There are ' + d3.format(',.0f')(GP_location[i]['Total']) +' patients registered to this practice.')
    .addTo(map_1) 
   }

    var baseMaps_map_1 = {
      "Show PCN boundary": pcn_boundary,
      // "Show GP practices": markers1, 
    };
  
     L.control
     .layers(null, baseMaps_map_1, { collapsed: false })
     .addTo(map_1);

});

// ! Population pyramid
var margin_middle = 80,
    pyramid_plot_width = (height/2) - (margin_middle/2),
    male_zero = pyramid_plot_width,
    female_zero = pyramid_plot_width + margin_middle;

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
    "; registered population; January 2022"   
   );
 });

  var age_levels = ["0-4 years", "5-9 years", "10-14 years", "15-19 years", "20-24 years", "25-29 years", "30-34 years", "35-39 years", "40-44 years", "45-49 years", "50-54 years", "55-59 years", "60-64 years", "65-69 years", "70-74 years", "75-79 years", "80-84 years", "85-89 years", "90-94 years", '95+ years']

PCN_pyramid_data.sort(function(a,b) {
  return age_levels.indexOf(a.Age_group) > age_levels.indexOf(b.Age_group)});

2// Filter to get out chosen dataset
chosen_pcn_pyramid_data = PCN_pyramid_data.filter(function(d,i){
  return d.Area_name === chosen_pcn_pyramid_area })

chosen_pcn_pyramid_summary_data = PCN_data.filter(function(d,i){
    return d.PCN_Name === chosen_pcn_pyramid_area }) 
 
d3.select("#pcn_age_structure_text_1").html(function (d) {
  return (
   "There are estimated to be <b class = 'extra'>" +
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
  '<b class = "extra">' +
  d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['65+ years']) +
  ' </b>patients are aged 65+ and over, this is ' +
  d3.format('.1%')(chosen_pcn_pyramid_summary_data[0]['65+ years'] / chosen_pcn_pyramid_summary_data[0]['Total'])
  );
});

d3.select("#pcn_age_structure_text_3").html(function (d) {
 return (
  '<b class = "extra">' +
  d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['0-15 years']) +
  '</b> are aged 0-15 and <b class = "extra">'+
  d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['16-64 years']) +
  '</b> are aged 16-64.'
 );
 });

// find the maximum data value on either side
 var maxPopulation_static_pyr = Math.max(
  d3.max(chosen_pcn_pyramid_data, function(d) { return d['Patients']; })
);

if(maxPopulation_static_pyr < 2000) {
  maxPopulation_static_pyr  = Math.ceil(maxPopulation_static_pyr / 200) * 200
}

if(maxPopulation_static_pyr >= 2000 && maxPopulation_static_pyr < 3000) {
  maxPopulation_static_pyr  = Math.ceil(maxPopulation_static_pyr / 250) * 250
}

if(maxPopulation_static_pyr >= 3000) {
    maxPopulation_static_pyr  = Math.ceil(maxPopulation_static_pyr / 500) * 500
}

// the scale goes from 0 to the width of the pyramid plotting region. We will invert this for the left x-axis
var x_static_pyramid_scale_male = d3.scaleLinear()
 .domain([0, maxPopulation_static_pyr])
 .range([male_zero, (0 + margin_middle/4)])
 .nice();

var xAxis_static_pyramid = svg_pcn_pyramid
 .append("g")
 .attr("transform", "translate(0," + height + ")")
 .call(d3.axisBottom(x_static_pyramid_scale_male).ticks(6))

 var x_static_pyramid_scale_female = d3.scaleLinear()
 .domain([0, maxPopulation_static_pyr])
 .range([female_zero, (height - margin_middle/4)])
 .nice();

var xAxis_static_pyramid_2 = svg_pcn_pyramid
 .append("g")
 .attr("transform", "translate(0," + height + ")")
 .call(d3.axisBottom(x_static_pyramid_scale_female).ticks(6));

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
   .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Patients']); })
   .attr("height", y_pyramid_wsx.bandwidth())
   .attr("fill", "#0099ff")
 
svg_pcn_pyramid
  .selectAll("myRect")
  .data(chosen_pcn_pyramid_data)
  .enter()
  .append("rect")
  .attr("class", "pyramid_1")
  .attr("x", function(d) { return male_zero - wsx_pyramid_scale_bars(d['Patients']); })
  .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
  .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Patients']); })
  .attr("height", y_pyramid_wsx.bandwidth())
  .attr("fill", "#ff6600")
   
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
       "There are estimated to be <b class = 'extra'>" +
        d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['Total']) +
        ' </b>patients registered to ' +
        chosen_pcn_pyramid_summary_data[0]['Practices'] +
         ' partnering practices in ' +
        chosen_pcn_pyramid_area + 
        ' as at January 2022.'   
       );
     });
    
    d3.select("#pcn_age_structure_text_2").html(function (d) {
     return (
       '<b class = "extra">' +
      d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['65+ years']) +
      ' </b>patients are aged 65+ and over, this is ' +
      d3.format('.1%')(chosen_pcn_pyramid_summary_data[0]['65+ years'] / chosen_pcn_pyramid_summary_data[0]['Total'])
      );
    });
    
    d3.select("#pcn_age_structure_text_3").html(function (d) {
      return (
        '<b class = "extra">' +
       d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['0-15 years']) +
       '</b> are aged 0-15 and <b class = "extra">'+
       d3.format(',.0f')(chosen_pcn_pyramid_summary_data[0]['16-64 years']) +
       '</b> are aged 16-64.'
       );
      });

  svg_pcn_pyramid.selectAll(".pyramid_1").remove();

  var maxPopulation_static_pyr = Math.max(
    d3.max(chosen_pcn_pyramid_data, function(d) { return d['Patients']; })
  );

if(maxPopulation_static_pyr < 2000) {
  maxPopulation_static_pyr  = Math.ceil(maxPopulation_static_pyr / 200) * 200
}

if(maxPopulation_static_pyr >= 2000 && maxPopulation_static_pyr < 3000) {
  maxPopulation_static_pyr  = Math.ceil(maxPopulation_static_pyr / 250) * 250
}

if(maxPopulation_static_pyr >= 3000) {
    maxPopulation_static_pyr  = Math.ceil(maxPopulation_static_pyr / 500) * 500
}

x_static_pyramid_scale_male
  .domain([0, maxPopulation_static_pyr])
  
x_static_pyramid_scale_female 
  .domain([0, maxPopulation_static_pyr])
  
wsx_pyramid_scale_bars 
  .domain([0,maxPopulation_static_pyr])

xAxis_static_pyramid 
  .transition()
  .duration(1000)
  .call(d3.axisBottom(x_static_pyramid_scale_male).ticks(6));
 
 xAxis_static_pyramid_2
 .transition()
 .duration(1000)
 .call(d3.axisBottom(x_static_pyramid_scale_female).ticks(6));

 svg_pcn_pyramid
   .selectAll("myRect")
   .data(chosen_pcn_pyramid_data)
   .enter()
   .append("rect")
   .attr("class", "pyramid_1")
   .attr("x", female_zero)
   .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
   .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Patients']); })
   .attr("height", y_pyramid_wsx.bandwidth())
   .attr("fill", "#0099ff")
 
svg_pcn_pyramid
  .selectAll("myRect")
  .data(chosen_pcn_pyramid_data)
  .enter()
  .append("rect")
  .attr("class", "pyramid_1")
  .attr("x", function(d) { return male_zero - wsx_pyramid_scale_bars(d['Patients']); })
  .attr("y", function(d) { return y_pyramid_wsx(d.Age_group); })
  .attr("width", function(d) { return wsx_pyramid_scale_bars(d['Patients']); })
  .attr("height", y_pyramid_wsx.bandwidth())
  .attr("fill", "#ff6600")

});

// ! Deprivation map 

// Specify that this code should run once the PCN_geojson data request is complete
$.when(Deprivation_geojson).done(function () {

// lsoa_data = Deprivation_geojson.responseJSON.features
// console.log(lsoa_data)

// Create a leaflet map (L.map) in the element map_1_id
  var map_2 = L.map("map_2_id");
   
  // add the background and attribution to the map
  L.tileLayer(tileUrl, { attribution })
   .addTo(map_2);
    
  var lsoa_boundary = L.geoJSON(Deprivation_geojson.responseJSON, { style: lsoa_deprivation_colour })
   .addTo(map_2)
   .bindPopup(function (layer) {
      return (
        "LSOA: <Strong>" +
        layer.feature.properties.LSOA11CD +
        "</Strong>.<br><br>This LSOA is in <Strong>" +
        layer.feature.properties.PCN_Name +
        "</Strong> in " + 
        layer.feature.properties.LTLA +
         "<br><br>This neighbourhood is in " +
        layer.feature.properties.IMD_2019_decile +
        ' and is ranked ' +
        d3.format(',.0f')(layer.feature.properties.IMD_2019_rank) +
        ' out of 32,844 small areas in England.'
      );
   });

   var PCN_boundary_overlay = L.geoJSON(PCN_geojson.responseJSON, { style: pcn_boundary_overlay_colour })
  //  .addTo(map_2);
  
   var Core20_LSOAs = L.geoJson(Deprivation_geojson.responseJSON, {filter: core_20Filter, style: core20_deprivation_colour})
  //  .addTo(map_2)
   .bindPopup(function (layer) {
    return (
      "LSOA: <Strong>" +
      layer.feature.properties.LSOA11CD +
      "</Strong>.<br><br>This LSOA is in <Strong>" +
      layer.feature.properties.PCN_Name +
      "</Strong> in " + 
      layer.feature.properties.LTLA +
       "<br><br>This neighbourhood is in " +
      layer.feature.properties.IMD_2019_decile +
      ' and is ranked ' +
      d3.format(',.0f')(layer.feature.properties.IMD_2019_rank) +
      ' out of 32,844 small areas in England.'
    );
 });

   function core_20Filter(feature) {
     if (feature.properties.IMD_2019_decile === "10% most deprived" | feature.properties.IMD_2019_decile === 'Decile 2') return true
   }
   
   map_2.fitBounds(lsoa_boundary.getBounds());

   var baseMaps_map_2 = {
    "Neighbourhoods (LSOA deprivation) ": lsoa_boundary,
    "Show PCN boundary lines": PCN_boundary_overlay,
    "Show most deprived 20% of<br>neighbourhoods (national rankings)": Core20_LSOAs, 
  };

   L.control
   .layers(null, baseMaps_map_2, { collapsed: false })
   .addTo(map_2);

  // Categorical legend 
var legend_map_2 = L.control({position: 'bottomright'});
legend_map_2.onAdd = function (map_2) {
    var div = L.DomUtil.create('div', 'info legend'),
        grades = ["10% most deprived", "Decile 2", "Decile 3", "Decile 4", "Decile 5", "Decile 6", "Decile 7", "Decile 8","Decile 9", "10% least deprived"], // Note that you have to print the labels, you cannot use the object deprivation_deciles
        labels = ['Nationally ranked<br>deprivation deciles'];
    // loop through our density intervals and generate a label with a colored square for each interval
    for (var i = 0; i < grades.length; i++) {
        div.innerHTML +=
        labels.push(
            '<i style="background:' + lsoa_covid_imd_colour_func(grades[i] + 1) + '"></i> ' +
            grades[i] );
    }
    div.innerHTML = labels.join('<br>');
    return div;
};
legend_map_2.addTo(map_2);

//    // Add a pin and zoom in.
//    var marker_chosen = L.marker([0, 0]).addTo(map_2);

//    //search event
//    $(document).on("click", "#btnPostcode", function () {
//      var input = $("#txtPostcode").val();
//      var url = "https://api.postcodes.io/postcodes/" + input;
 
//      post(url).done(function (postcode) {
//        var chosen_lsoa = postcode["result"]["lsoa"];
//        var chosen_ltla = postcode['result']['admin_district'];
//        var chosen_lat = postcode["result"]["latitude"];
//        var chosen_long = postcode["result"]["longitude"];
 
//        marker_chosen.setLatLng([chosen_lat, chosen_long]);
//        map_2.setView([chosen_lat, chosen_long], 11);

//   if(wsx_areas.includes(chosen_ltla)){
//     console.log(Deprivation_geojson.responseJSON.features[0].properties)
// // var lsoa_summary_data_chosen = Deprivation_geojson.feature.properties.filter(function (d) {
//   // return d.LSOA11NM == chosen_lsoa;
//   // });
 
// console.log(postcode["result"])
// // console.log(lsoa_summary_data_chosen)

//        d3.select("#local_pinpoint_1").html(function (d) {
//         return 'This postcode is in ' + chosen_lsoa + chosen_ltla;
//       });
//       d3.select("#local_pinpoint_2").html(function (d) {
//         return "More detail will appear here.";
//       });

// }
 
//       });
//     });

//  //enter event - search
//  $("#txtPostcode").keypress(function (e) {
//   if (e.which === 13) {
//     $("#btnPostcode").click();
//   }
// });

// //ajax call
// function post(url) {
//   return $.ajax({
//     url: url,
//     success: function () {
//       //woop
//     },
//     error: function (desc, err) {
//       $("#result_text").html("Details: " + desc.responseText);

//       d3.select("#local_pinpoint_1").html(function (d) {
//         return "The postcode you entered does not seem to be valid, please check and try again.";
//       });
//       d3.select("#local_pinpoint_2").html(function (d) {
//         return "This could be because there is a problem with the postcode look up tool we are using.";
//       });
//     },
//   });
// }

  });

// ! Numbers in each quintile

// PCN table 
function loadTable_pcn_numbers_in_quintiles(PCN_deprivation_data) {
  const tableBody = document.getElementById("pcn_table_deprivation_1");
  var dataHTML = "";

  for (let item of PCN_deprivation_data) {
    dataHTML += `<tr><td>${item.Area_Name}</td><td>${d3.format(",.0f")(item["20% most deprived"])}</td><td>${d3.format('.1%')(item["Proportion_most"])}</td><td>${d3.format(",.0f")(item["Total"])}</td></tr>`;
  }
  tableBody.innerHTML = dataHTML;
}

// PCN figure
var svg_stacked_pcn_quintiles = d3.select("#stacked_pcn_quintiles_figure")
.append("svg")
.attr("width", width)
.attr("height", height)
.append("g")
.attr("transform", "translate(" + 50 + "," + 0 + ")");

var quintile_fields = ["Proportion_most", 'Proportion_q2', 'Proportion_q3', 'Proportion_q4', 'Proportion_least'];

var quintile_label = d3
  .scaleOrdinal()
  .domain(quintile_fields)
  .range(['Most deprived 20%', 'Quintile 2', 'Quintile 3', 'Quintile 4', 'Least deprived 20%']);

  var colour_quintile_label = d3
  .scaleOrdinal()
  .domain(quintile_fields)
  .range(["#0033cc", 
  "#00b0f0",
  '#e4e4e4',
  '#ffc000',
  '#e46c0a']);

// Create a list with an item for each PCN and display the colour in the border 
quintile_fields.forEach(function (item, index) {
  var list = document.createElement("li");
  list.innerHTML = quintile_label(item);
  list.className = "key_list";
  list.style.borderColor = colour_quintile_label(index);
  var tt = document.createElement("div");
  tt.style.borderColor = colour_quintile_label(index);
  var tt_h3_1 = document.createElement("h3");
  tt_h3_1.innerHTML = item;
  tt.appendChild(tt_h3_1);
  var div = document.getElementById("quintile_key");
  div.appendChild(list);
});

var PCN_new_order = PCN_deprivation_data.map(function (d) {
  return d.Area_Name;
})

var stackedData_quintiles_fig = d3.stack().keys(quintile_fields)(PCN_deprivation_data);

// Bars going horizontally
var x_stacked_pcn_quintiles = d3
.scaleLinear()
.domain([0, 1])
.range([width *.25, width -100])
.nice();

var xAxis_stacked_quintiles = svg_stacked_pcn_quintiles
.append("g")
.attr("transform", "translate(0," + (height - 50) + ")")
.call(d3.axisBottom(x_stacked_pcn_quintiles).tickFormat(d3.format(".0%")));

var y_stacked_pcn_quintiles = d3
  .scaleBand()
  .domain(PCN_new_order)
  .range([20, (height -50)])
  .padding([0.2]);

var yAxis_stacked_pcn_quintiles = svg_stacked_pcn_quintiles
  .append("g")
  .attr("transform", "translate(" + width * .25 + ",0)")
  .call(d3.axisLeft(y_stacked_pcn_quintiles));

var bars_stacked_pcn_quintiles = svg_stacked_pcn_quintiles
  .append("g")
  .selectAll("g")
  .data(stackedData_quintiles_fig)
  .enter()
  .append("g")
  .attr("fill", function (d) {
    return colour_quintile_label(d.key);
  })
  .selectAll("rect")
  .data(function (d) {
    return d;
  })
  .enter()
  .append("rect")
  .attr("x", function (d) {
    return x_stacked_pcn_quintiles(d[0]);
  })
  .attr("y", function (d) {
    return y_stacked_pcn_quintiles(d.data.Area_Name);
  })
  .attr("width", function (d) {
    return x_stacked_pcn_quintiles(d[1]) - x_stacked_pcn_quintiles(d[0]);
  })
  .attr("height", y_stacked_pcn_quintiles.bandwidth())

// ! Filtered GP table

// We need to create a dropdown button for the user to choose which area to be displayed on the figure.
d3.select("#select_pcn_table_2_button")
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
var chosen_pcn_table_2_area = d3
  .select("#select_pcn_table_2_button")
  .property("value");

// Use the value from chosen_pcn_pyramid_area to populate a title for the figure. This will be placed as the element 'selected_pcn_table_2_title' on the webpage
d3.select("#selected_pcn_table_2_title").html(function (d) {
  return (
    "Table 2 - number of patients registered to practices in " +
    chosen_pcn_table_2_area +
    "; patients living in the most deprived neighbourhoods; registered population; January 2022"   
   );
 });

chosen_PCN_gp_quintile = GP_location.filter(function(d,i){
  return d.PCN_Name === chosen_pcn_table_2_area})

// GP table 
function loadTable_gp_numbers_in_quintiles(chosen_PCN_gp_quintile) {
  const tableBody = document.getElementById("gp_table_deprivation_2");
  var dataHTML = "";

  for (let item of chosen_PCN_gp_quintile) {
    dataHTML += `<tr><td>${item.Area_Name}</td><td>${d3.format(",.0f")(item["20% most deprived"])}</td><td>${d3.format('.1%')(item["Proportion_most"])}</td><td>${d3.format(",.0f")(item["Total"])}</td></tr>`;
  }
  tableBody.innerHTML = dataHTML;
} 

 // The .on('change) part says when the drop down menu (select element) changes then retrieve the new selected area name and then use it to update the selected_pcn_table_2_title element 
d3.select("#select_pcn_table_2_button").on("change", function (d) {
  var chosen_pcn_table_2_area = d3
    .select("#select_pcn_table_2_button")
    .property("value");
   
    d3.select("#selected_pcn_table_2_title").html(function (d) {
      return (
        "Table 2 - number of patients registered to practices in " +
        chosen_pcn_table_2_area +
        "; patients living in the most deprived neighbourhoods; registered population; January 2022"   
       );
     });

     chosen_PCN_gp_quintile = GP_location.filter(function(d,i){
      return d.PCN_Name === chosen_pcn_table_2_area})
    
    loadTable_gp_numbers_in_quintiles(chosen_PCN_gp_quintile)

    })

    
// ! MSOA map

function getUnemploymentColor(d) {
  return d > 5 ? '#0B0405' :
         d > 4  ? '#382A54' :
         d > 3  ? '#395D9C' :
         d > 2  ? '#3497A9' :
         d > 1   ? '#60CEAC' :
         '#DEF5E5' ;

}

// Create a function to add stylings to the polygons in the leaflet map
function msoa_unemployment_colour(feature) {
  return {
    fillColor: getUnemploymentColor(feature.properties.Unemployment),
    // color: getUnemploymentColor(feature.properties.Unemployment),
    color: '#999999',
    weight: 1,
    fillOpacity: 0.85,
  };
}

function getLEColor(d) {
  return d < 75 ? '#03051A' :
         d < 77.5 ? '#3F1B44' :
         d < 80 ? '#841E5A' :
         d < 82.5 ? '#CB1B4F' :
         d < 85 ? '#F06043' :
         d < 87.5 ? '#F6AA82' :
         d < 90 ? '#FFEDA0' :
                  '#FAEBDD';
}

function male_le_colour(feature) {
  return {
    fillColor: getLEColor(feature.properties.Male_LE_at_birth),
    // color: getLEColor(feature.properties.Male_LE_at_birth),
    color: '#dbdbdb',
    weight: 1,
    fillOpacity: 0.85,
  };
}

function female_le_colour(feature) {
  return {
    fillColor: getLEColor(feature.properties.Female_LE_at_birth),
    color: getLEColor(feature.properties.Female_LE_at_birth),
    color: '#dbdbdb',
    weight: 1,
    fillOpacity: 0.85,
  };
}

function getSARColor(d) {
  return d < 70 ? '#30123B' :
         d < 80 ? '#4777EF' :
         d < 90 ? '#1BD0D5' :
         d < 100 ? '#62FC6B' :
         d < 110 ? '#D2E935' :
         d < 120 ? '#FE9B2D' :
         d < 130 ? '#DB3A07' :
                  '#7A0403';
}

msoa_hospital_admission_colour
function msoa_hospital_admission_colour(feature) {
  return {
    fillColor: getSARColor(feature.properties.Hosp_all_cause),
    color: getSARColor(feature.properties.Hosp_all_cause),
    color: '#dbdbdb',
    weight: 1,
    fillOpacity: 0.85,
  };
}

// Specify that this code should run once the PCN_geojson data request is complete
$.when(msoa_geojson).done(function () {

// Create a leaflet map (L.map) in the element map_3_id for unemployement and fuel poverty
var map_3 = L.map("map_3_id");
     
// add the background and attribution to the map
  L.tileLayer(tileUrl, { attribution })
  .addTo(map_3);
      
var msoa_unemployment_boundary = L.geoJSON(msoa_geojson.responseJSON, { style: msoa_unemployment_colour })
  .addTo(map_3)
  .bindPopup(function (layer) {
    return (
     "MSOA: <Strong>" +
      layer.feature.properties.Area_Code +
      " (" +
      layer.feature.properties.msoa11hclnm +
      ")</Strong>.<br><br>Proportion of working age (16-64 year olds) claming benefit principally for the reason of being unemployed: <Strong>" +
      layer.feature.properties.Unemployment + 
      "% in 2019/20 </Strong>"
      );
    });
  
var PCN_boundary_overlay = L.geoJSON(PCN_geojson.responseJSON, { style: pcn_boundary_overlay_colour })
  
map_3.fitBounds(msoa_unemployment_boundary.getBounds());
  
var baseMaps_map_3 = {
  "Proportion unemployed": msoa_unemployment_boundary,
};

var overlay_maps_pcn = {
  "Show PCN boundary lines": PCN_boundary_overlay,
}; 
  
L.control
 .layers(baseMaps_map_3, overlay_maps_pcn, { collapsed: false })
 .addTo(map_3);

var legend_map_3 = L.control({position: 'bottomright'});

legend_map_3.onAdd = function (map_3) {

    var div = L.DomUtil.create('div', 'info legend'),
        grades = [0, 1, 2, 3, 4, 5],
        labels = ['% age 16-64<br>unemployed'];

    // loop through our density intervals and generate a label with a colored square for each interval
    for (var i = 0; i < grades.length; i++) {
        div.innerHTML +=
        labels.push(
            '<i style="background:' + getUnemploymentColor(grades[i] + 1) + '"></i> ' +
            grades[i] + (grades[i + 1] ? '&ndash;' + grades[i + 1] + '%' : '%+'));
    }
    div.innerHTML = labels.join('<br>');
    return div;
};

legend_map_3.addTo(map_3);

// Create a leaflet map (L.map) in the element map_4_id for Life expectancy and mortality
  var map_4 = L.map("map_4_id");
     
// add the background and attribution to the map
 L.tileLayer(tileUrl, { attribution })
 .addTo(map_4);

var msoa_male_le_boundary = L.geoJSON(msoa_geojson.responseJSON, { style: male_le_colour })
  .addTo(map_4)
  .bindPopup(function (layer) {
   return (
    "MSOA: <Strong>" +
   layer.feature.properties.Area_Code +
   " (" +
   layer.feature.properties.msoa11hclnm +
   ")</Strong>.<br><br>Male life expectancy: " +
   d3.format(',.1f')(layer.feature.properties.Male_LE_at_birth) +
   " years<br>Female life expectancy: " +
   d3.format(',.1f')(layer.feature.properties.Female_LE_at_birth) +
   ' years' 
   );
 });

 var msoa_female_le_boundary = L.geoJSON(msoa_geojson.responseJSON, { style: female_le_colour })
//  .addTo(map_4)
 .bindPopup(function (layer) {
  return (
   "MSOA: <Strong>" +
  layer.feature.properties.Area_Code +
  " (" +
  layer.feature.properties.msoa11hclnm +
  ")</Strong>.<br><br>Male life expectancy: " +
  d3.format(',.1f')(layer.feature.properties.Male_LE_at_birth) +
  " years<br>Female life expectancy: " +
  d3.format(',.1f')(layer.feature.properties.Female_LE_at_birth) +
  ' years' 
  );
});

var baseMaps_map_4 = {
  "Male life expectancy at birth": msoa_male_le_boundary,
  "Female life expectancy at birth": msoa_female_le_boundary,
  };

 L.control
 .layers(baseMaps_map_4, overlay_maps_pcn, { collapsed: false })
 .addTo(map_4);
 
 map_4.fitBounds(msoa_male_le_boundary.getBounds());

var legend_map_4 = L.control({position: 'bottomright'});

legend_map_4.onAdd = function (map_4) {

    var div = L.DomUtil.create('div', 'info legend'),
        grades = [72.5, 75, 77.5, 80, 82.5, 85, 87.5, 90],
        labels = ['Life expectancy<br>at birth (years)'];

    // loop through our density intervals and generate a label with a colored square for each interval
    for (var i = 0; i < grades.length; i++) {
        div.innerHTML +=
        labels.push(
            '<i style="background:' + getLEColor(grades[i] + 1) + '"></i> ' +
            grades[i] + (grades[i + 1] ? '&ndash;' + grades[i + 1] + ' years' : '+ years'));
    }
    div.innerHTML = labels.join('<br>');
    return div;
};

legend_map_4.addTo(map_4);

// Create a leaflet map (L.map) in the element map_3_id for unemployement and fuel poverty
var map_5 = L.map("map_5_id");
     
// add the background and attribution to the map
  L.tileLayer(tileUrl, { attribution })
  .addTo(map_5);
      
var msoa_hospital_admissions_all_boundary = L.geoJSON(msoa_geojson.responseJSON, { style: msoa_hospital_admission_colour })
  .addTo(map_5)
  .bindPopup(function (layer) {
    return (
     "MSOA: <Strong>" +
      layer.feature.properties.Area_Code +
      " (" +
      layer.feature.properties.msoa11hclnm +
      ")</Strong>.<br><br>Standardised Admission Ratio: <Strong>" +
      d3.format(',.1f')(layer.feature.properties.Hosp_all_cause) + 
      " per 100 estimated in 2015/16 - 19/20</Strong><br><br>A value higher than 100 indicates a higher than expected number of admissions given local population age profile."
      );
    });
  
var PCN_boundary_overlay = L.geoJSON(PCN_geojson.responseJSON, { style: pcn_boundary_overlay_colour })
  
map_5.fitBounds(msoa_hospital_admissions_all_boundary.getBounds());
  
var baseMaps_map_5 = {
  "Emergency hospital admissions (all cause) SAR": msoa_hospital_admissions_all_boundary,
};
 
L.control
 .layers(baseMaps_map_5, overlay_maps_pcn, { collapsed: false })
 .addTo(map_5);

var legend_map_5 = L.control({position: 'bottomright'});
legend_map_5.onAdd = function (map_5) {
    var div = L.DomUtil.create('div', 'info legend'),
        grades = [60, 70, 80, 90, 100, 110, 120, 130],
        labels = ['Emergency hospital<br>admission SAR'];
    // loop through our density intervals and generate a label with a colored square for each interval
    for (var i = 0; i < grades.length; i++) {
        div.innerHTML +=
        labels.push(
            '<i style="background:' + getSARColor(grades[i] + 1) + '"></i> ' +
            grades[i] + (grades[i + 1] ? '&ndash;' + grades[i + 1] + ' per 100' : '+ per 100'));
    }
    div.innerHTML = labels.join('<br>');
    return div;
};
legend_map_5.addTo(map_5);

});
  