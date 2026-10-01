extends GutTest
## Covers the arithmetic [FrameProbe] reports with. The probe itself drives real
## demos and needs a GPU, so it is exercised by running it, not here.


func test_average_and_worst_frame_rate() -> void:
	var times := PackedFloat32Array([1.0 / 60.0, 1.0 / 60.0, 1.0 / 60.0, 1.0 / 20.0])
	var summary := FrameProbe.summarize(times)
	assert_eq(summary["frames"], 4)
	assert_almost_eq(summary["average_fps"], 4.0 / (3.0 / 60.0 + 1.0 / 20.0), 0.01)
	assert_almost_eq(summary["worst_fps"], 20.0, 0.01, "The one hitch")


func test_no_frames_reports_zero_rather_than_dividing_by_it() -> void:
	var summary := FrameProbe.summarize(PackedFloat32Array())
	assert_eq(summary["frames"], 0)
	assert_eq(summary["average_fps"], 0.0)


func test_peak_speed_finds_the_fastest_cell() -> void:
	var field := FluidField.new()
	field.resize(4, 4)
	assert_eq(FrameProbe.peak_speed(field), 0.0, "A still tank")
	field.set_cell_velocity(2, 1, Vector2(3.0, 4.0))
	field.set_cell_velocity(0, 3, Vector2(-1.0, 0.0))
	assert_almost_eq(FrameProbe.peak_speed(field), 5.0, 0.0001)
