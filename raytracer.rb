require 'mathn'
require 'matrix'
require 'bundler/setup'
require 'chunky_png'

class Scene

  attr_accessor :light_source, :objects, :ambient_coeff, :diffuse_coeff

end

class Ray

  attr_reader :from, :direction

  def initialize from, direction
    @from = from
    @direction = direction
  end

end

class Sphere

  attr_reader :origin, :radius, :color, :reflectivity

  def initialize origin, radius, color, reflectivity=0.5
    @origin = origin
    @radius = radius
    @color = color
    @reflectivity = reflectivity
  end

  def ambient_coeff scene
    scene.ambient_coeff
  end

  def diffuse_coeff scene
    scene.diffuse_coeff
  end

  def light_source scene
    scene.light_source.origin
  end

  def color_for ray, tracer, scene
    intersections = intersections_by ray
    if intersections
      intersection_point = intersections.first
      surface_normal = normal_at(intersection_point)

      # Specular reflection
      reflected_ray_direction = bounce_direction ray.direction, surface_normal
      reflected_ray = Ray.new(intersection_point, reflected_ray_direction)
      reflected_color = tracer.trace_ray reflected_ray, self
      
      # Diffuse reflection
      light_vector = (light_source(scene) - intersection_point).normalize
      shade = light_vector.dot(surface_normal)
      shade = 0 if shade < 0
      color_coeff = ambient_coeff(scene) + shade * diffuse_coeff(scene)
      diffuse_color = color.map {|v| v * color_coeff}
      
      # Combine colors
      final_color = if reflected_color
        diffuse_color.zip(reflected_color).map {|d,r| d*(1 - reflectivity) + r*reflectivity}
      else
        diffuse_color
      end

      final_color.map {|v| v.to_i}
    end
  end

  # Returns intersection points as [p1, p2] where p1 is the closer intersection
  def intersections_by ray
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

      result = points
        .zip(distances)
        .select {|p,dist| dist >= 0}
        .sort {|(p1,d1), (p2,d2)| d1 <=> d2}
        .map {|p,dist| p}

      result unless result.empty?
    end
  end

  def normal_at point_on_sphere
    (point_on_sphere - origin).normalize
  end

  def bounce_direction ray_direction, normal_direction
    v = ray_direction
    n = normal_direction

    c1 = -v.dot(n)
    (v + (2 * c1 * n)).normalize
  end

end

class LightSource < Sphere

  def initialize origin, radius, color, reflectivity=0.5
    super 
  end

  def color_for ray, tracer, scene
    color if intersections_by(ray)
  end

end

class Tracer

  attr_reader :scene, :camera_location, :frame_z

  def initialize
    light_source = LightSource.new Vector[0,1000,0], 400, [255,255,255], 1.0
    
    scene = Scene.new
    scene.diffuse_coeff = 0.8
    scene.ambient_coeff = 0.2
    scene.light_source = light_source
    scene.objects = [
      light_source,
      Sphere.new(Vector[-200,0,-200], 150, [0,0,255], 0.9),
      Sphere.new(Vector[200,0,-200], 150, [255,0,0], 0.9)
    ]
    
    
    @scene = scene
    @frame_z = 50
    @camera_location = Vector[0,0,200]
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
        
  def trace_ray ray, from=nil
    scene.objects.map {|o| from != o && o.color_for(ray, self, scene)}.detect {|c| c}
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


file_name = File.expand_path(ARGV.first || 'test.png')

Tracer.new.generate file_name
