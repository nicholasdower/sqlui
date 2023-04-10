# frozen_string_literal: true

# You know, pig stuff.
class Pigs
  NAMES = %w[
    babe misery piglet snowball squealer wilbur napoleon porky miss-piggy petunia betina
    belinda pumbaa hamm peppa-pig fifer fiddler practical-pig hampton-j piggy orson pua
    huxley gub-gub olivia piggy-bank arnold boss-hog
  ].freeze
  private_constant :NAMES

  POSSESSIVE_NAMES = NAMES.map { |name| "#{name}s" }
  private_constant :POSSESSIVE_NAMES

  NOUNS = %w[snout ear ears tail hoof hooves foot feet].freeze
  private_constant :NOUNS

  ADJECTIVES = %w[pink hairy plump round cute dirty smelly tiny adorable slimy dainty big cunning sneaky].freeze
  private_constant :ADJECTIVES

  GERUND_VERBS = %w[oinking squealing grunting rooting sniffing snorting wallowing trotting rolling].freeze
  private_constant :GERUND_VERBS

  VERBS = %w[oinks squeals grunts roots sniffs snorts wallows trots rolls swallows].freeze
  private_constant :VERBS

  ADVERBS = %w[hungrily loudly greedily angrily coyly playfully lazily noisily happily].freeze
  private_constant :ADVERBS

  FOOD_NOUNS = %w[trotter loin cutlet hock skin jowl cheek rump belly ham bacon back shoulder ear ears tail rib
                  tenderloin pork-chop roast sausage fatback fat tongue].freeze
  private_constant :FOOD_NOUNS

  PLURAL_FOOD_NOUNS = %w[ears trotters cutlets hocks jowls cheeks ribs spareribs pork-chops sausages steaks].freeze
  private_constant :PLURAL_FOOD_NOUNS

  FOOD_ADJECTIVES = %w[tasty meaty greasy chewy salty smoky juicy delicious crunchy fatty salted spicy savory succulent
                       moist flavorful tender sweet].freeze
  private_constant :FOOD_ADJECTIVES

  PIG_ON_PIG_VERBS = %w[snuggles cuddles chases sniffs watches smells cuddles oinks-at squeals-at grunts-at snorts-at
                        wallows-with roots-with trots-with rolls-with grins-at].freeze
  private_constant :PIG_ON_PIG_VERBS

  COMBOS = [
    [NAMES],
    [NAMES, %w[and], NAMES],
    [NAMES, %w[and], NAMES, %w[are], ADJECTIVES],
    [NAMES, PIG_ON_PIG_VERBS, NAMES],
    [GERUND_VERBS, NAMES],
    [NAMES, GERUND_VERBS],
    [NAMES, GERUND_VERBS, ADVERBS],
    [GERUND_VERBS, NAMES, %w[and], NAMES],
    [NAMES, %w[and], NAMES, GERUND_VERBS],
    [NAMES, %w[and], NAMES, GERUND_VERBS, ADVERBS],
    [NAMES, VERBS],
    [ADJECTIVES, NAMES],
    [NAMES, %w[is], ADJECTIVES],
    [ADJECTIVES, %w[and], ADJECTIVES, NAMES],
    [NAMES, VERBS, ADVERBS],
    [POSSESSIVE_NAMES, NOUNS],
    [POSSESSIVE_NAMES, ADJECTIVES, NOUNS],
    [POSSESSIVE_NAMES, ADJECTIVES, %w[and], ADJECTIVES, NOUNS],
    [ADJECTIVES, NOUNS],
    [POSSESSIVE_NAMES, FOOD_ADJECTIVES, FOOD_NOUNS],
    [POSSESSIVE_NAMES, FOOD_ADJECTIVES, PLURAL_FOOD_NOUNS],
    [NAMES, %w[has-a], FOOD_ADJECTIVES, FOOD_NOUNS],
    [NAMES, %w[has], FOOD_ADJECTIVES, PLURAL_FOOD_NOUNS],
    [FOOD_NOUNS],
    [FOOD_ADJECTIVES, FOOD_NOUNS],
    [FOOD_ADJECTIVES, FOOD_ADJECTIVES, FOOD_NOUNS],
    [%w[a one], FOOD_ADJECTIVES, FOOD_NOUNS],
    [%w[a one], FOOD_ADJECTIVES, FOOD_ADJECTIVES, FOOD_NOUNS],
    [PLURAL_FOOD_NOUNS],
    [FOOD_ADJECTIVES, PLURAL_FOOD_NOUNS],
    [FOOD_ADJECTIVES, FOOD_ADJECTIVES, PLURAL_FOOD_NOUNS],
    [%w[some two three four five six seven eight nine ten a-dozen a-plate-of a-bucket-of a-barrel-of],
     PLURAL_FOOD_NOUNS],
    [%w[some two three four five six seven eight nine ten a-dozen a-plate-of a-bucket-of a-barrel-of], FOOD_ADJECTIVES,
     PLURAL_FOOD_NOUNS],
    [%w[some two three four five six seven eight nine ten a-dozen a-plate-of a-bucket-of a-barrel-of], FOOD_ADJECTIVES,
     FOOD_ADJECTIVES, PLURAL_FOOD_NOUNS]
  ].freeze
  private_constant :COMBOS

  COMBO_COUNTS = COMBOS.map do |combo|
    size = 1
    used = []
    combo.each do |list|
      size *= list.size - used.count(list)
      used << list
    end
    size
  end
  private_constant :COMBO_COUNTS

  TOTAL_COMBOS = COMBO_COUNTS.sum
  private_constant :TOTAL_COMBOS

  COMBO_SUM = COMBO_COUNTS.each_with_object([0]).map do |i, j|
    j[0] = j[0] + i
  end
  private_constant :COMBO_SUM

  def self.total_combos
    TOTAL_COMBOS
  end

  def self.generate_phrase
    rand = rand(TOTAL_COMBOS)
    COMBOS.each_with_index do |combo, i|
      next unless rand < COMBO_SUM[i]

      used = []
      parts = []
      combo.each do |list|
        list -= used
        used << list.sample
        parts << used.last
      end
      return parts.join('-')
    end
  end
end
