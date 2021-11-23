virtual class shape;

	protected real width = 0;
	protected real height = 0;

	function new(real w, real h);
		width = w;
		height = h;
	endfunction : new

	pure virtual function real get_area();

	pure virtual function void print();

endclass : shape

class rectangle extends shape;

	function new(real width, real height);
		super.new(width, width);
	endfunction : new

	function real get_area();
		return (width * width);
	endfunction : get_area

	function void print();
		$display("Rectangle, w: %g, area %g", width,get_area());
	endfunction : print
endclass : rectangle


class square extends shape;

	function new(real width, real height);
		super.new(width, height);
	endfunction : new

	function real get_area();
		return (width * width);
	endfunction : get_area

	function void print();
		$display("Square, w: %g h: %g area %g", width, height, get_area());
	endfunction : print
endclass : square


class triangle extends shape;

	function new(real width, real height);
		super.new(width, width);
	endfunction : new

	function real get_area();
		return (width * width *0.5);
	endfunction : get_area

	function void print();
		$display("Triangle, w: %g, area %g", width,get_area());
	endfunction : print
endclass : triangle

class shape_factory;

	static function shape make_shape(string shape_type, real w, real h);
		rectangle rectangle_h;
		square square_h;
		triangle triangle_h;

		case (shape_type)
			"rectangle" : begin
				rectangle_h = new(w, h);
				return rectangle_h;
			end

			"square" : begin
				square_h = new(w, h);
				return square_h;
			end

			"triangle" : begin
				triangle_h = new(w, h);
				return triangle_h;
			end

			default :
				$fatal (1, {"No such shape: ", shape_type});

		endcase // case (shapes)

	endfunction : make_shape

endclass : shape_factory

class shape_reporter #(type T = shape);

	protected static T shape_storage[$];

	static function void collect_shapes(T l);
		shape_storage.push_back(l);
	endfunction : collect_shapes

	static function void report_shapes();
		real area_tot = 0;
		foreach (shape_storage[i]) begin
			shape_storage[i].print();
			area_tot = area_tot + shape_storage[i].get_area();
		end
		$display("Total area: %g", area_tot);
	endfunction : report_shapes
endclass : shape_reporter

module top;

	initial begin
		shape shape_h;
		rectangle rectangle_h;
		square square_h;
		triangle triangle_h;

		bit cast_ok;

		int data_file;
		real width;
		real height;
		string shape_name;

		data_file = $fopen("lab04part1_shapes.txt", "r");

		while($fscanf(data_file, "%s %f %f", shape_name, width, height) == 3) begin

			shape_h = shape_factory::make_shape(shape_name, width, height);

			case(shape_name)
				"rectangle" : begin
					cast_ok = $cast(rectangle_h, shape_h);
					if(!cast_ok)
						$fatal(1, "Failed to cast shape_h to rectangle_h");
					shape_reporter#(rectangle)::collect_shapes(rectangle_h);
				end

				"square" : begin
					cast_ok = $cast(square_h, shape_h);
					if(!cast_ok)
						$fatal(1, "Failed to cast shape_h to square_h");
					shape_reporter#(square)::collect_shapes(square_h);
				end

				"triangle" : begin
					cast_ok = $cast(triangle_h, shape_h);
					if(!cast_ok)
						$fatal(1, "Failed to cast shape_h to triangle_h");
					shape_reporter#(triangle)::collect_shapes(triangle_h);
				end
				
				default:
					$fatal(1, {"Where figures? This is", shape_name});
			endcase
		end
		
		shape_reporter#(rectangle)::report_shapes();
		shape_reporter#(square)::report_shapes();
		shape_reporter#(triangle)::report_shapes();
		
	end
endmodule : top