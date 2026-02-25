(function() {
  // Sort a grid by column index. type: 'str' or 'num'
  window.sortTable = function(gridId, colIndex, type) {
    var grid = document.getElementById(gridId);
    if (!grid) return;
    var rows = Array.from(grid.querySelectorAll('details.file-row'));
    var prevCol = parseInt(grid.dataset.sortCol, 10);
    var prevDir = grid.dataset.sortDir || 'asc';
    var dir = (prevCol === colIndex && prevDir === 'asc') ? 'desc' : 'asc';
    grid.dataset.sortCol = colIndex;
    grid.dataset.sortDir = dir;
    rows.sort(function(a, b) {
      var aCells = Array.from(a.querySelector('summary').children);
      var bCells = Array.from(b.querySelector('summary').children);
      var aVal = aCells[colIndex] ? (aCells[colIndex].dataset.value || '') : '';
      var bVal = bCells[colIndex] ? (bCells[colIndex].dataset.value || '') : '';
      var cmp = 0;
      if (type === 'num') {
        cmp = parseFloat(aVal) - parseFloat(bVal);
      } else {
        cmp = aVal.localeCompare(bVal);
      }
      return dir === 'asc' ? cmp : -cmp;
    });
    // Update sort indicator classes on header spans
    var spans = grid.querySelectorAll('.file-grid-header span');
    spans.forEach(function(span, i) {
      span.classList.remove('sort-asc', 'sort-desc');
      if (i === colIndex) span.classList.add(dir === 'asc' ? 'sort-asc' : 'sort-desc');
    });
    // Re-append sorted details rows after the header
    rows.forEach(function(row) {
      grid.appendChild(row);
    });
  };
})();