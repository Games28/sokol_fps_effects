@vs vs_default

layout(binding=0) uniform vs_params {
    mat4 u_model;
	mat4 u_mvp;
};

in vec3 v_pos;
in vec3 v_norm;
in vec2 v_uv;

out vec3 pos;
out vec3 norm;
out vec2 uv;

void main() {
    gl_Position=u_mvp*vec4(v_pos, 1);
    pos=(u_model*vec4(v_pos, 1)).xyz;
    norm=normalize(mat3(u_model)*v_norm);
    uv=v_uv;
}

@end

@fs fs_default

layout(binding=0) uniform texture2D default_tex;
layout(binding=0) uniform sampler default_smp;

layout(binding=1) uniform fs_params {
	vec4 u_tint;
	vec2 u_tl;
	vec2 u_br;
	vec3 u_view_pos;
	int u_num_lights;
	vec4 u_light_pos[16];
	vec4 u_light_col[16];

};

in vec3 pos;
in vec3 norm;
in vec2 uv;


out vec4 frag_color;

void main() {
	const float amb_mag=1;//0-1
	const vec3 amb_col=vec3(0.03);
	
	const float shininess=64;//32-256
	const float spec_mag=1;//0-1

	const float att_k0=1.0;
	const float att_k1=0.09;
	const float att_k2=0.032;

	//srgb->linear
	vec3 base_col_srgb=texture(sampler2D(default_tex, default_smp),u_tl + uv * (u_br - u_tl)).rgb;
	vec3 base_col=pow(base_col_srgb, vec3(2.2));

	vec3 n=normalize(norm);
	vec3 v=normalize(u_view_pos- pos);

	//start with ambient
	vec3 col=amb_col*base_col*amb_mag;
	for(int i=0; i<u_num_lights; i++) {
		vec3 l_pos=u_light_pos[i].xyz;
		vec3 l_col=u_light_col[i].rgb;

		vec3 l=l_pos-pos;
		float dist=length(l);
		l/=dist;

		//diffuse(Lambert)
		float n_dot_l=max(0, dot(n, l));
		vec3 diffuse=l_col*base_col*n_dot_l;

		//blinn-phong specular
		vec3 h=normalize(l+v);//half-vector
		float n_dot_h=max(0, dot(n, h));
		float spec_factor=pow(n_dot_h, shininess);
		vec3 specular=l_col*spec_factor*spec_mag;

		//attenuation (apply equally to all channels)
		float att=1/(att_k0+att_k1*dist+att_k2*dist*dist);

		col+=att*(diffuse+specular);
	}
	
	//linear->srgb
	vec3 col_srgb=pow(col, vec3(1/2.2));
	frag_color = vec4(col_srgb, 1) * u_tint;
}

@end

@program default vs_default fs_default

///////// 2d texture with/without animation //////////////////

@vs vs_texview

in vec2 v_pos;
in vec2 v_uv;

out vec2 uv;

void main()
{
	gl_Position = vec4(v_pos, .5, 1);
	uv.x = v_uv.x;
	uv.y = -v_uv.y;
}

@end

@fs fs_texview

layout(binding = 0) uniform texture2D texview_tex;
layout(binding = 0) uniform sampler texview_smp;

layout(binding = 0) uniform fs_texview_params
{
	vec4 u_tint;
	vec2 u_tl;
	vec2 u_br;
};

in vec2 uv;

out vec4 frag_color;

void main()
{
	vec4 col =  texture(sampler2D(texview_tex, texview_smp), u_tl + uv * (u_br - u_tl));
	frag_color = u_tint * col;
}

@end

@program texview vs_texview fs_texview

/*========== BILLBOARD SHADER =============*/

@vs vs_billboard

layout(binding=0) uniform vs_billboard_params {
	mat4 u_model;
	mat4 u_mvp;
	vec2 u_tl, u_br;
};

in vec3 i_pos;
in vec3 i_norm;
in vec2 i_uv;

out vec3 pos;
out vec3 norm;
out vec2 uv;

void main() {
	pos=(u_model*vec4(i_pos, 1)).xyz;
	norm=normalize(mat3(u_model)*i_norm);
	uv=u_tl+i_uv*(u_br-u_tl);
	gl_Position=u_mvp*vec4(i_pos, 1);
}

@end

@fs fs_billboard

layout(binding=1) uniform fs_billboard_params {
	vec3 u_eye_pos;
	vec3 u_light_pos;
	vec3 u_tint;
};

layout(binding=0) uniform texture2D u_billboard_tex;
layout(binding=0) uniform sampler u_billboard_smp;

in vec3 pos;
in vec3 norm;
in vec2 uv;

out vec4 o_frag_col;

void main() {
	vec3 N=normalize(norm);
	vec3 L=normalize(u_light_pos-pos);
	vec3 V=normalize(u_eye_pos-pos);
	vec3 R=reflect(-L, N);

	float amb_mag=.2;
	float diff_mag=.7*max(dot(N, L), 0);
	vec4 tex_col=texture(sampler2D(u_billboard_tex, u_billboard_smp), uv);
	vec3 base_col=u_tint*tex_col.rgb;

	//white specular
	float spec_mag=.3*pow(max(dot(R, V), 0), 32);
	vec3 spec=spec_mag*vec3(1, 1, 1);

	o_frag_col=vec4(base_col*(amb_mag+diff_mag)+spec, 1);
}

@end


@program billboard vs_billboard fs_billboard