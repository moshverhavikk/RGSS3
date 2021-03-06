#==============================================================================
# ** Quasi Collision Map v1.2
#  Requires Quasi Movement [version 1.2.1 +]
#    http://quasixi.com/movement/
#  Requires Quasi Module [version 0.4.5]
#    http://quasixi.com/quasi-module/
#  If links are down, try my github
#    https://github.com/quasixi/RGSS3
#==============================================================================
#  Allows the use of an image with collisions.  Using this you can setup
# a pseudo perfect pixel collision.
#  To have a map use a collision map, use the following in the maps notetag
#    <cm=NAME>
#  Map note tags are found in the map properties
#  Set Name to the name of the collision map you want to use, this image
#  should be inside the parallax folder!
#==============================================================================
# How to install:
#  - Place this below Quasi Movement(link is above)
#  - Place this above Quasi Optimize(optional script)
#  - Make sure the version of Quasi Movement is the required version.
#  - Follow instructions below
#==============================================================================
module Quasi
  module CollisionMap
#------------------------------------------------------------------------------
# Setup:
#  COLLISION is the color that will be not be passable, use 
#    Quasi.color("hex color code")
#  Hex color is usually easy to find in most image editors, just don't
#  forget to leave out the # infront of the code!
#------------------------------------------------------------------------------
    COLLISION = Quasi.color("ff0000")
#------------------------------------------------------------------------------
#  REGIONS allow you to mark a new region type (pixel regions) based off
#  of a color.  To find out the pixel region someone is on use:
#    $game_map.pixel_region_id(px, py)
#  *NOTE* Make sure you use pixel values, so not their x/y values!!
#  This is setup inside a hash in the following format:
#    "hex color code" => id,
#  *NOTE* This doesn't relate with current regions, so pixel region 1
#  is not map region 1!!
#  **Completely optional, and does not need to be used**
#------------------------------------------------------------------------------
    REGIONS   = {
      "00ff00" => 1,  # Green is pixel region 1
      "0000ff" => 2   # Blue is pixel region 2
    }
#------------------------------------------------------------------------------
#  OPT is set to an integer which can help optimize the collision detection
#  What this does, it scans every X pixel, so if OPT was set to 5, it will scan
#  every 5th pixel when needed.  Depending on how detailed your collision maps
#  are you should use 1 or 2.
#------------------------------------------------------------------------------
    OPT = 1
#------------------------------------------------------------------------------
#  For testing purposes, set the bottom value to true to see the collision map.
#  Only shows during play testing.
#------------------------------------------------------------------------------
    SHOWMAP    = true
    MAPBLEND   = 0
    MAPOPACITY = 120
  end
end
#==============================================================================
# Change Log
#------------------------------------------------------------------------------
# v1.2 - 12/29/14
#      - Fixed a bug, forgot to readd update method
# --
# v1.1 - 12/28/14
#      - Fixed a bug with disposed bitmap
# --
# v1 - Released
#==============================================================================#
# By Quasi (http://quasixi.com/) || (https://github.com/quasixi/RGSS3)
#  - 12/23/14
#==============================================================================#
#   ** Stop! Do not edit anything below, unless you know what you      **
#   ** are doing!                                                      **
#==============================================================================#
$imported = {} if $imported.nil?
$imported["Quasi"] = 0 if $imported["Quasi"].nil?
$imported["Quasi_Movement"] = 0 if $imported["Quasi_Movement"].nil?
$imported["Quasi_CollisionMap"] = 1.2

if $imported["Quasi_Movement"] >= 1.23 && $imported["Quasi"] >= 0.45

#==============================================================================
# ** Game_Map
#------------------------------------------------------------------------------
#  This class handles maps. It includes scrolling and passage determination
# functions. The instance of this class is referenced by $game_map.
#==============================================================================

class Game_Map
  attr_reader     :collisionmap
  #--------------------------------------------------------------------------
  # * Setup
  #--------------------------------------------------------------------------
  alias :qmcm_gm_setup    :setup
  def setup(map_id)
    qmcm_gm_setup(map_id)
    setup_collisionmap
  end
  #--------------------------------------------------------------------------
  # * Grab collisions from Image
  #--------------------------------------------------------------------------
  def setup_collisionmap
    @collisionmap = Cache.parallax(@map.collisionmap) rescue nil
  end
  #--------------------------------------------------------------------------
  # * Checks for collision
  #--------------------------------------------------------------------------
  def collisionmap_passable?(px, py)
    return true unless @collisionmap
    return @collisionmap.get_pixel(px, py) != Quasi::CollisionMap::COLLISION
  end
  #--------------------------------------------------------------------------
  # * Get Pixel Region ID
  #--------------------------------------------------------------------------
  def pixel_region_id(px, py)
    return 0 unless @collisionmap
    region = @collisionmap.get_pixel(px, py)
    id = Quasi::CollisionMap::REGIONS[region.to_hex]
    return id ? id : 0
  end
end

#==============================================================================
# ** Game_CharacterBase
#------------------------------------------------------------------------------
#  This base class handles characters. It retains basic information, such as 
# coordinates and graphics, shared by all characters.
#==============================================================================

class Game_CharacterBase
  #--------------------------------------------------------------------------
  # * Determine if Tile is Passable
  #--------------------------------------------------------------------------
  alias :qmcm_gc_tilebox?    :tilebox_passable?
  def tilebox_passable?(x, y, d)
    collisionmap_passable?(x, y, d) && qmcm_gc_tilebox?(x, y, d)
  end
  #--------------------------------------------------------------------------
  # * Check if collided with collision map
  #--------------------------------------------------------------------------
  def collisionmap_passable?(x, y, d)
    pass = []
    checks = 0
    edge = edge(x, y, d)
    x1 = edge[0][0].truncate
    x2 = edge[1][0].truncate
    y1 = edge[0][1].truncate
    y2 = edge[1][1].truncate
    for x in x1..x2
      for y in y1..y2
        axis = direction == 2 || direction == 8 ? y : x
        axis1 = axis == x ? x1 : y1
        axis2 = axis == x ? x2 : y2
        firstfinal = axis == axis1 || axis == axis2
        next unless axis % Quasi::CollisionMap::OPT == 0 || firstfinal
        pass << $game_map.collisionmap_passable?(x, y)
      end
    end
    return pass.all?{|pos| pos == true}
  end
end

#==============================================================================
# ** RPG::Map
#==============================================================================

class RPG::Map
  #--------------------------------------------------------------------------
  # * Collision Map notetag
  #--------------------------------------------------------------------------
  def collisionmap
    if @collisionmap.nil?
      @collisionmap = Quasi::regex(@note, /<cm=(.*)>/i, :string)
    end
    return @collisionmap
  end
end

#==============================================================================
# ** Spriteset_Map
#------------------------------------------------------------------------------
#  This class brings together map screen sprites, tilemaps, etc. It's used
# within the Scene_Map class.
#==============================================================================

class Spriteset_Map
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  alias :qmcm_sm_init    :initialize
  def initialize
    qmcm_sm_init
    create_cmap
  end
  #--------------------------------------------------------------------------
  # * Start Collision Map Display
  #--------------------------------------------------------------------------
  def create_cmap
    return unless $game_map
    return unless $game_map.collisionmap
    return unless Quasi::CollisionMap::SHOWMAP && $TEST
    @cmap = Sprite.new
    @cmap.bitmap     = $game_map.collisionmap
    @cmap.blend_type = Quasi::CollisionMap::MAPBLEND
    @cmap.opacity    = Quasi::CollisionMap::MAPOPACITY
  end
  #--------------------------------------------------------------------------
  # * Free Collision Map
  #--------------------------------------------------------------------------
  def dispose_cmap
    return unless @cmap
    @cmap.bitmap.dispose if @cmap.bitmap
    @cmap.dispose
  end
  #--------------------------------------------------------------------------
  # * Refresh Characters
  #--------------------------------------------------------------------------
  alias :qmcm_sm_refresh    :refresh_characters
  def refresh_characters
    qmcm_sm_refresh
    dispose_cmap
    create_cmap
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  alias :cmap_sm_update   :update
  def update
    cmap_sm_update
    update_cmap
  end
  #--------------------------------------------------------------------------
  # * Update Collision Map
  #--------------------------------------------------------------------------
  def update_cmap
    return unless @cmap
    return if @cmap.disposed?
    @cmap.ox = $game_map.display_x * 32
    @cmap.oy = $game_map.display_y * 32
  end
end
else
  msgbox(sprintf("[Quasi Collison Map] Requires Quasi movement."))
end
