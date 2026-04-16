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

    scaled_max = max_val/divisor
    return scaled_series, unit_label, scaled_max
  end

  # Calculates a clean, human-readable step size for the Y-axis
  def self.calculate_nice_axis(max_value, target_ticks = 4)
    # Fallback for flatlines
    return { increment: 1, max: target_ticks } if max_value <= 0.0 
    
    # 1. Figure out roughly how big each step should be
    rough_step = max_value.to_f / target_ticks
    
    # 2. Find the mathematical magnitude (e.g., 1_000_000 for Megabits)
    magnitude = 10 ** Math.log10(rough_step).floor
    
    # 3. Normalize the step to a decimal between 1.0 and 9.99
    fraction = rough_step / magnitude
    
    # 4. Snap it to a clean interval of 1, 2, 5, or 10
    nice_fraction = if fraction <= 1.5
                      1.0
                    elsif fraction <= 3.0
                      2.0
                    elsif fraction <= 7.0
                      5.0
                    else
                      10.0
                    end
                    
    # 5. Multiply back up to the original scale
    increment = nice_fraction * magnitude
    
    # 6. Calculate the new, perfectly rounded maximum value
    nice_max = (max_value / increment).ceil * increment
    
    { increment: increment, max: nice_max }
  end
end