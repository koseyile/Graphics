#ifndef COMMON_MACROS_INCLUDED
#define COMMON_MACROS_INCLUDED

// ------------------------------------------------------------
//	helper macro to sample texture

// sample without alpha
#define tex2DRGB(tex, coord) (tex2D(tex, coord).rgb)

// sample with alpha
#if defined(ALPHA_ORIG)
	#define tex2DRGBA(tex, coord) tex2D(tex, coord)
#elif defined(ALPHA_R)
	#define tex2DRGBA(tex, coord) half4(tex2D(tex, coord).rgb, tex2D(tex##_Alpha, coord).r)
#elif defined(ALPHA_G)
	#define tex2DRGBA(tex, coord) half4(tex2D(tex, coord).rgb, tex2D(tex##_Alpha, coord).g)
#else //ALPHA_B
	#define tex2DRGBA(tex, coord) half4(tex2D(tex, coord).rgb, tex2D(tex##_Alpha, coord).b)
#endif

// only sample alpha
#if defined(ALPHA_ORIG)
	#define tex2DA(tex, coord) tex2D(tex, coord).a
#elif defined(ALPHA_R)
	#define tex2DA(tex, coord) tex2D(tex##_Alpha, coord).r
#elif defined(ALPHA_G)
	#define tex2DA(tex, coord) tex2D(tex##_Alpha, coord).g
#else //ALPHA_B
	#define tex2DA(tex, coord) tex2D(tex##_Alpha, coord).b
#endif

// ---------------------------------------------------------------------------
//	helper macro to fix bug about comparing expression in some android devices

#if SHADER_API_GLES3
	#define step(a, x)			ceil(saturate(x - a))

	// Unity 5.4.3
	// for some android, '(int)a == 0' is the only one available comparing expression
	// do not use ceil(x), because it will suffer precision problem when x is small (such like 0.01)
	#define clip(x)				if((int)max(0, floor((x) + 1)) == 0) discard
	#define greaterEqual(a, b)	((int)max(0, floor((b) - (a) + 1)) == 0)
	#define less(a, b)			((int)max(0, floor((a) - (b) + 1)) == 0)
	#define equal(a, b)			((int)max(0, floor(abs((a) - (b)) + 0.999)) == 0)
#else
	#define greaterEqual(a, b)	((a) >= (b))
	#define less(a, b)			((a) < (b))
	#define equal(a, b)			((a) == (b))
#endif


#endif // COMMON_INCLUDED