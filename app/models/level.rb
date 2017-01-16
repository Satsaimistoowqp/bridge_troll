class Level < ActiveRecord::Base
  COLORS = %w(blue green gold purple orange pink)

  default_scope { order(:num) }

  belongs_to :course
  validates :num, presence: true,
            inclusion: {
              in: (1..5),
              message: "Must be between 1 and 5"
            }
  validates :color, presence: true,
            inclusion: {
              in: COLORS,
              message: "Must be one of: #{COLORS.sort.join(', ')}"
            }
  validates :title, presence: true
  validates :level_description, presence: true
  serialize :level_description, Array
  alias_attribute :description, :level_description

  def level_description_bullets
    level_description.map { |line| "* #{line}" }.join("\n")
  end

  def level_description_bullets=(value)
    self.level_description = value.split("\n").map { |line| line.gsub(/^\s*\*\s*/, '').strip }
  end
end
