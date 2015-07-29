require 'mathn'
require 'matrix'
require 'bundler/setup'
require 'chunky_png'

class Scene

  attr_accessor :light_source, :objects, :ambient_coeff

  def light_source_location
    light_source.origin
  end

  def shadowed? the_object, location
    light_direction = (light_source_location - location).normalize
    shadow_ray = Ray.new(location, light_direction)
    objects
      .select {|o| o != the_object}
      .detect {|o| o.point_of_intersection shadow_ray}
  end

end

class Ray

  attr_reader :from, :direction

  def initialize from, direction
    @from = from
    @direction = direction
  end

end

module ReflectiveObject

  attr_accessor :reflectivity

  def color_for ray, order, tracer, scene
    light_source_location = scene.light_source_location
    intersection = point_of_intersection ray
    
    if intersection
      light_vector = (light_source_location - intersection).normalize
      surface_normal = normal_at intersection

      shadowed = scene.shadowed? self, intersection

      # Specular reflection
      reflected_ray_direction = bounce_direction ray.direction, surface_normal
      reflected_ray = Ray.new(intersection, reflected_ray_direction)
      reflected_color = order < 4 ? tracer.trace_ray(reflected_ray, order + 1, self) : nil
      
      # Diffuse reflection
      shade = light_vector.dot(surface_normal)
      shade = 0 if shade < 0 || shadowed
      color_coeff = [scene.ambient_coeff, shade].max
      diffuse_color = color.map {|v| v * color_coeff}
      
      # Combine colors
      final_color = 
        if reflected_color
          diffuse_color
            .zip(reflected_color)
            .map {|d,r| d * (1 - reflectivity) + r * reflectivity}
        else
          diffuse_color
        end
      
      final_color.map {|v| v.to_i}
    end
  end

  def bounce_direction ray_direction, normal_direction
    v = ray_direction
    n = normal_direction

    c1 = -v.dot(n)
    (v + (2 * c1 * n)).normalize
  end

end

class Sphere
  include ReflectiveObject
  
  attr_reader :origin, :radius, :color

  def initialize origin, radius, color, reflectivity=0.5
    @origin = origin
    @radius = radius
    @color = color

    self.reflectivity = reflectivity
  end
  
  def point_of_intersection ray
    p0 = ray.from
    c0 = origin
    r = radius
    d = ray.direction
    
    a = d.dot(d)
    b = 2 * d.dot(p0 - c0)
    c = (p0 - c0).dot(p0 - c0) - r*r

    root_term = b*b - 4*a*c

    unless root_term < 0
      t1 = (-b + Math.sqrt(root_term)) / (2*a)
      t2 = (-b - Math.sqrt(root_term)) / (2*a)

      p1 = (p0 + t1 * d)
      p2 = (p0 + t2 * d)

      points = [p1,p2]
      distances = points.map {|p| (p - p0).dot(d)}

      points
        .zip(distances)
        .select {|p,dist| dist >= 0}
        .sort {|(p1,d1), (p2,d2)| d1 <=> d2}
        .map {|p,dist| p}
        .first
    end
  end

  def normal_at point_on_sphere
    (point_on_sphere - origin).normalize
  end

end

class LightSource < Sphere

  def initialize origin, radius, color, reflectivity=0.5
    super 
  end

  def color_for ray, order, tracer, scene
    color if point_of_intersection ray
  end

end

class Tracer

  attr_reader :scene, :camera_location, :frame_z

  def initialize camera_location, scene
    @scene = scene
    @frame_z = 50
    @camera_location = camera_location
  end
  
  def trace_rays frame_width, frame_height
    # frame rectangle assumed to be centered at [0,0,frame_z]
    y = frame_height/2

    while y > -frame_height/2 do
      x = -frame_width/2
      while x < frame_width/2 do
        point_on_frame = Vector[x,y,frame_z]

        ray_direction = (point_on_frame - camera_location).normalize
        ray = Ray.new(camera_location, ray_direction)
        
        yield [x,y,trace_ray(ray)]
        x += 1
      end
      y -= 1
    end
  end
        
  def trace_ray ray, order = 0, from = nil
    (scene.objects + [scene.light_source]).map {|o| from != o && o.color_for(ray, order, self, scene)}.detect {|c| c}
  end

  def generate save_path
    w = 400
    h = 400
    png = ChunkyPNG::Image.new(w, h, ChunkyPNG::Color::TRANSPARENT)
    
    trace_rays w,h do |(x,y,color)|
      r,g,b = color || [0,0,0]
      png_x = (w/2 + x).to_i
      png_y = h - (h/2 + y).to_i
      png[png_x, png_y] = ChunkyPNG::Color.rgba(r,g,b,255)
    end

    png.save(save_path)

    puts "Done!"
  end

end

camera_location = Vector[0,0,200]
scene = Scene.new
scene.ambient_coeff = 0.2
scene.light_source = LightSource.new Vector[0,0,10000], 400, [255,255,255], 1.0
scene.objects = [
  Sphere.new(Vector[0,0,-400], 150, [0,0,255], 0.9),
  Sphere.new(Vector[0,0,500], 200, [255,0,0], 0.9)
]

file_name = File.expand_path(ARGV.first || 'test.png')

Tracer.new(camera_location, scene).generate file_name
