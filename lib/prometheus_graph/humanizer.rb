module Humanizer
  UNITS = %w[b/s Kb/s Mb/s Gb/s Tb/s Pb/s]

  def self.auto_scale(series_data)
    # 1. Flatten all values to find the absolute maximum across all lines
    all_values = series_data.flat_map { |s| s[:values] }
    max_val = all_values.compact.max || 0

    # 2. Determine the exponent (power of 1000)
    # log1000(x) = log10(x) / 3
    exponent = max_val > 0 ? (Math.log10(max_val) / 3).to_i : 0
    
    # Cap the exponent so we don't go past Pb/s (index 5)
    exponent = [exponent, UNITS.size - 1].min 
    
    # 3. The divisor (e.g., 1,000,000 for Mb/s)
    divisor = 1000.0 ** exponent
    unit_label = UNITS[exponent]

    # 4. Scale all data points
    # puts series_data[0][:values]
    scaled_series = series_data.map do |s|
      {
        label: s[:label],
        values: s[:values].map { |v| v / divisor }
      }
    end

    return scaled_series, unit_label
  end
end