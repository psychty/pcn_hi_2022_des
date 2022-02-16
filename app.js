// Footprint of PCNs

// L. is leaflet
var tileUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
var attribution =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Contains Ordnance Survey data © Crown copyright and database right 2022';

// Add AJAX request for data
var ltla = $.ajax({
  url: "./data/lad_simple.geojson",
  dataType: "json",
  success: console.log("LTLA boundary data successfully loaded."),
  error: function (xhr) {
    alert(xhr.statusText);
  },
});

function leColour(feature) {
  return {
    // fillColor: setleColour(feature.properties.PCN),
    // color: setleColour(feature.properties.PCN),
    fillColor: "yellow",
    weight: 1,
    fillOpacity: 0.5,
  };
}

// Specify that this code should run once the county data request is complete
$.when(ltla).done(function () {
  var map = L.map("map_1_id").setView([50.8379, -0.7827], 10);

  var basemap = L.tileLayer(tileUrl, { attribution }).addTo(map);

  var ltla_boundary = L.geoJSON(ltla.responseJSON, { style: leColour })
    .addTo(map)
    .bindPopup(function (layer) {
      return (
        "Local authority: <Strong>" +
        layer.feature.properties.LAD19NM +
        "</Strong>"
      );
    });

  map.fitBounds(ltla_boundary.getBounds());
});
