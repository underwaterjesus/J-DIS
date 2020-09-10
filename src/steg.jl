using Images, FileIO, Printf, ArgMacros, Suppressor

@suppress begin
    using ImageView, Gtk.ShortNames             #suppress Gtk warnings on Windows machines
end

function pretty_print(x)                        #for nicer testing/debug array printing

    if(ndims(x) == 2)
        for i in 1:size(x)[1]
            for j in 1:size(x)[2]
                print(x[i, j], " - ")
            end
            println()
        end
    elseif(ndims(x) == 1)
        for i in 1:length(x)
            try
                @printf("0x%x\n", x[i])
            catch e
                println(x[i])
            end
        end
    end
    println()
end

function get_ext(s)
    if(s == nothing)
        return nothing
    elseif( length(s) < 5)
        return nothing
    end

    return s[length(s) - 3 : length(s)]
end

function encode_pdf(args::Dict)
    if( !( isfile(args["in_file"]) ) || !( isfile(args["hidden"]) ) )
        println("NO EXIST") ## TODO: real error message
        exit(0)
    end

    #TODO:  -check file extensions
    #       -handle images other than .png

    img = load( File(format"PNG", args["in_file"]) )
    doc = open( args["hidden"], "r" )
    n = size(img)[1]
    m = size(img)[2]

    f_size = filesize(doc)
    if( f_size * 4 > ( (3(n * m)) - 17) )
        println("TOO BIG") ## TODO: real error message
        exit(0)
    end

    seek(doc, 0)
    

    #pretty_print(img)

    expanded_img = Array{UInt8,1}(undef, 3(n * m))

    for i in 1:n
        for j in 1:m

            global t = ( ((i - 1) * m) + j )

            expanded_img[t * 3] = reinterpret( UInt8, img[i, j].b )
            expanded_img[(t * 3) - 1] = reinterpret( UInt8, img[i, j].g )
            expanded_img[(t * 3) - 2] = reinterpret( UInt8, img[i, j].r )

        end
    end

    for i in 1:length(expanded_img)                 ###############
        expanded_img[i] = expanded_img[i] & 0xfc    # clear 2 LSBs
    end                                             ###############

    #pretty_print(expanded_img)

    chars = Array{UInt8,1}(undef, filesize(doc) + 16)
    num_chars = UInt32(0)
    while(!(eof(doc)))
        num_chars += 1
        global chr = read(doc, UInt8)
        chars[num_chars] = UInt8(chr)
    end
    println(num_chars)
    #pretty_print(chars)

    #=
    a::UInt8  = 0x00
    b::UInt8  = 0x00
    c::UInt8  = 0x00
    d::UInt8  = 0x00
    =#

    expanded_img[16] |= UInt8( num_chars & 0x03)
    expanded_img[15] |= UInt8( (num_chars >> 2) & 0x03)
    expanded_img[14] |= UInt8( (num_chars >> 4) & 0x03)
    expanded_img[13] |= UInt8( (num_chars >> 6) & 0x03)
    expanded_img[12] |= UInt8( (num_chars >> 8) & 0x03)
    expanded_img[11] |= UInt8( (num_chars >> 10) & 0x03)
    expanded_img[10] |= UInt8( (num_chars >> 12) & 0x03)
    expanded_img[9] |= UInt8( (num_chars >> 14) & 0x03)
    expanded_img[8] |= UInt8( (num_chars >> 16) & 0x03)
    expanded_img[7] |= UInt8( (num_chars >> 18) & 0x03)
    expanded_img[6] |= UInt8( (num_chars >> 20) & 0x03)
    expanded_img[5] |= UInt8( (num_chars >> 22) & 0x03)
    expanded_img[4] |= UInt8( (num_chars >> 24) & 0x03)
    expanded_img[3] |= UInt8( (num_chars >> 26) & 0x03)
    expanded_img[2] |= UInt8( (num_chars >> 28) & 0x03)
    expanded_img[1] |= UInt8( (num_chars >> 30) & 0x03)

    for i in 5:length(chars) + 4

        a = UInt8( chars[i - 4] & 0x03 )
        b = UInt8( (chars[i - 4] >> 2) & 0x03 )
        c = UInt8( (chars[i - 4] >> 4) & 0x03 )
        d = UInt8( (chars[i - 4] >> 6) & 0x03 )

        expanded_img[i*4] = expanded_img[i*4] | a
        expanded_img[i*4-1] = expanded_img[i*4-1] | b
        expanded_img[i*4-2] = expanded_img[i*4-2] | c
        expanded_img[i*4-3] = expanded_img[i*4-3] | d

    end

    expanded_img[length(expanded_img)] &= 0xfc
    expanded_img[length(expanded_img)] |= 0x02

    #pretty_print(expanded_img)

    irgb = Array{RGB{N0f8},1}(undef, n * m)
    red = UInt8(0)
    green = UInt8(0)
    blue = UInt8(0)

    for i in 1:length(expanded_img)
        global z = ( (i-1)÷3 ) + 1
        global md = i % 3
    
        if(md == 1)
            red = expanded_img[i]
        elseif(md == 2)
            green = expanded_img[i]
        elseif(md == 0)
            blue = expanded_img[i]
            irgb[z] = RGB( reinterpret( N0f8, UInt8(red) ), reinterpret( N0f8, UInt8(green) ), reinterpret( N0f8, UInt8(blue) ) )
        end
    end

    #pretty_print(irgb)

    out = Array{RGB{N0f8},2}(undef, n, m)

    for i in 1:n
        for j in 1:m
            x = ( (i - 1) * m ) + j
            out[i, j] = RGB(irgb[x].r, irgb[x].g, irgb[x].b); #@printf("i:%d - j:%d - x:%d\n", i, j, x);
        end
    end

    #pretty_print(out)

    if( args["out_file"] == nothing )
        guidict = imshow(out)

        con = Condition()

        win = guidict["gui"]["window"]

        signal_connect(win, :destroy) do widget
            notify(con)
        end

        wait(con)
    else
        save( File(format"PNG", args["out_file"]), out )
    end

end

function encode_txt(args::Dict)
    if( !( isfile(args["in_file"]) ) || !( isfile(args["hidden"]) ) )
        println("NO EXIST") ## TODO: real error message
        exit(0)
    end

    #TODO:  -check file extensions
    #       -handle images other than .png

    img = load( File(format"PNG", args["in_file"]) )
    doc = open( args["hidden"], "r" )
    n = size(img)[1]
    m = size(img)[2]

    f_size = filesize(doc)
    if( f_size * 16 > ( (3(n * m)) - 17) )
        println("TOO BIG") ## TODO: real error message
        exit(0)
    end

    seek(doc, 0)
    

    #pretty_print(img)

    expanded_img = Array{UInt8,1}(undef, 3(n * m))

    for i in 1:n
        for j in 1:m

            global t = ( ((i - 1) * m) + j )

            expanded_img[t * 3] = reinterpret( UInt8, img[i, j].b )
            expanded_img[(t * 3) - 1] = reinterpret( UInt8, img[i, j].g )
            expanded_img[(t * 3) - 2] = reinterpret( UInt8, img[i, j].r )

        end
    end

    for i in 1:length(expanded_img)                 ###############
        expanded_img[i] = expanded_img[i] & 0xfc    # clear 2 LSBs
    end                                             ###############

    #pretty_print(expanded_img)

    chars = Array{UInt32,1}(undef, filesize(doc) + 16)
    num_chars = UInt32(0)
    while(!(eof(doc)))
        num_chars += 1
        global chr = read(doc, Char)
        chars[num_chars] = UInt32(chr)
    end
    println(num_chars)
    #pretty_print(chars)

    #=
    a::UInt8  = 0x00
    b::UInt8  = 0x00
    c::UInt8  = 0x00
    d::UInt8  = 0x00
    =#

    expanded_img[16] |= UInt8( num_chars & 0x03)
    expanded_img[15] |= UInt8( (num_chars >> 2) & 0x03)
    expanded_img[14] |= UInt8( (num_chars >> 4) & 0x03)
    expanded_img[13] |= UInt8( (num_chars >> 6) & 0x03)
    expanded_img[12] |= UInt8( (num_chars >> 8) & 0x03)
    expanded_img[11] |= UInt8( (num_chars >> 10) & 0x03)
    expanded_img[10] |= UInt8( (num_chars >> 12) & 0x03)
    expanded_img[9] |= UInt8( (num_chars >> 14) & 0x03)
    expanded_img[8] |= UInt8( (num_chars >> 16) & 0x03)
    expanded_img[7] |= UInt8( (num_chars >> 18) & 0x03)
    expanded_img[6] |= UInt8( (num_chars >> 20) & 0x03)
    expanded_img[5] |= UInt8( (num_chars >> 22) & 0x03)
    expanded_img[4] |= UInt8( (num_chars >> 24) & 0x03)
    expanded_img[3] |= UInt8( (num_chars >> 26) & 0x03)
    expanded_img[2] |= UInt8( (num_chars >> 28) & 0x03)
    expanded_img[1] |= UInt8( (num_chars >> 30) & 0x03)

    for i in 2:length(chars) + 1

        a = UInt8( chars[i - 1] & 0x03 )
        b = UInt8( (chars[i - 1] >> 2) & 0x03 )
        c = UInt8( (chars[i - 1] >> 4) & 0x03 )
        d = UInt8( (chars[i - 1] >> 6) & 0x03 )
        e = UInt8( (chars[i - 1] >> 8) & 0x03 )
        f = UInt8( (chars[i - 1] >> 10) & 0x03 )
        g = UInt8( (chars[i - 1] >> 12) & 0x03 )
        h = UInt8( (chars[i - 1] >> 14) & 0x03 )
        i_ = UInt8( (chars[i - 1] >> 16) & 0x03 )
        j = UInt8( (chars[i - 1] >> 18) & 0x03 )
        k = UInt8( (chars[i - 1] >> 20) & 0x03 )
        l = UInt8( (chars[i - 1] >> 22) & 0x03 )
        m_ = UInt8( (chars[i - 1] >> 24) & 0x03 )
        n_ = UInt8( (chars[i - 1] >> 26) & 0x03 )
        o = UInt8( (chars[i - 1] >> 28) & 0x03 )
        p = UInt8( (chars[i - 1] >> 30) & 0x03 )

        expanded_img[i*16] = expanded_img[i*16] | a
        expanded_img[i*16-1] = expanded_img[i*16-1] | b
        expanded_img[i*16-2] = expanded_img[i*16-2] | c
        expanded_img[i*16-3] = expanded_img[i*16-3] | d
        expanded_img[i*16-4] = expanded_img[i*16-4] | e
        expanded_img[i*16-5] = expanded_img[i*16-5] | f
        expanded_img[i*16-6] = expanded_img[i*16-6] | g
        expanded_img[i*16-7] = expanded_img[i*16-7] | h
        expanded_img[i*16-8] = expanded_img[i*16-8] | i_
        expanded_img[i*16-9] = expanded_img[i*16-9] | j
        expanded_img[i*16-10] = expanded_img[i*16-10] | k
        expanded_img[i*16-11] = expanded_img[i*16-11] | l
        expanded_img[i*16-12] = expanded_img[i*16-12] | m_
        expanded_img[i*16-13] = expanded_img[i*16-13] | n_
        expanded_img[i*16-14] = expanded_img[i*16-14] | o
        expanded_img[i*16-15] = expanded_img[i*16-15] | p

    end

    expanded_img[length(expanded_img)] &= 0xfc

    #pretty_print(expanded_img)

    irgb = Array{RGB{N0f8},1}(undef, n * m)
    red = UInt8(0)
    green = UInt8(0)
    blue = UInt8(0)

    for i in 1:length(expanded_img)
        global z = ( (i-1)÷3 ) + 1
        global md = i % 3
    
        if(md == 1)
            red = expanded_img[i]
        elseif(md == 2)
            green = expanded_img[i]
        elseif(md == 0)
            blue = expanded_img[i]
            irgb[z] = RGB( reinterpret( N0f8, UInt8(red) ), reinterpret( N0f8, UInt8(green) ), reinterpret( N0f8, UInt8(blue) ) )
        end
    end

    #pretty_print(irgb)

    out = Array{RGB{N0f8},2}(undef, n, m)

    for i in 1:n
        for j in 1:m
            x = ( (i - 1) * m ) + j
            out[i, j] = RGB(irgb[x].r, irgb[x].g, irgb[x].b); #@printf("i:%d - j:%d - x:%d\n", i, j, x);
        end
    end

    #pretty_print(out)

    if( args["out_file"] == nothing )
        guidict = imshow(out)

        con = Condition()

        win = guidict["gui"]["window"]

        signal_connect(win, :destroy) do widget
            notify(con)
        end

        wait(con)
    else
        save( File(format"PNG", args["out_file"]), out )
    end

end

function encode_driver(extension::String, args::Dict)
    if(extension == nothing)
        println("file has no extension")
        exit(0)
    elseif( extension == ".pdf")
        encode_pdf(args)
    elseif( extension == ".txt" )
        encode_txt(args)
    end
end

function decode(args::Dict)

    if( !( isfile(args["in_file"]) ) )
        println("NO EXIST") ## TODO: real error message
        exit(0)
    end

    img = load( File(format"PNG", args["in_file"]) )
    n = size(img)[1]
    m = size(img)[2]

    #pretty_print(img)

    expanded_img = Array{UInt8,1}(undef, 3(n * m))

    for i in 1:n
        for j in 1:m

            global t = ( ((i - 1) * m) + j )

            expanded_img[t * 3] = reinterpret( UInt8, img[i, j].b )
            expanded_img[(t * 3) - 1] = reinterpret( UInt8, img[i, j].g )
            expanded_img[(t * 3) - 2] = reinterpret( UInt8, img[i, j].r )

        end
    end

    file_type = expanded_img[length(expanded_img)]
    file_type &= 0x03

    if(file_type == 0x00)
    ################################################################################
        chars = zeros(UInt32, length(expanded_img) ÷ 16)

        for i in 1:length(chars)

            x = UInt32(0)

            x |= ( UInt32( expanded_img[i * 16] ) ) & 0x03 
            x |= ( UInt32( expanded_img[(i * 16) - 1] ) & 0x03 ) << 2
            x |= ( UInt32( expanded_img[(i * 16) - 2] ) & 0x03 ) << 4
            x |= ( UInt32( expanded_img[(i * 16) - 3] ) & 0x03 ) << 6
            x |= ( UInt32( expanded_img[(i * 16) - 4] ) & 0x03 ) << 8
            x |= ( UInt32( expanded_img[(i * 16) - 5] ) & 0x03 ) << 10
            x |= ( UInt32( expanded_img[(i * 16) - 6] ) & 0x03 ) << 12
            x |= ( UInt32( expanded_img[(i * 16) - 7] ) & 0x03 ) << 14
            x |= ( UInt32( expanded_img[(i * 16) - 8] ) & 0x03 ) << 16
            x |= ( UInt32( expanded_img[(i * 16) - 9] ) & 0x03 ) << 18
            x |= ( UInt32( expanded_img[(i * 16) - 10] ) & 0x03 ) << 20
            x |= ( UInt32( expanded_img[(i * 16) - 11] ) & 0x03 ) << 22
            x |= ( UInt32( expanded_img[(i * 16) - 12] ) & 0x03 ) << 24
            x |= ( UInt32( expanded_img[(i * 16) - 13] ) & 0x03 ) << 26
            x |= ( UInt32( expanded_img[(i * 16) - 14] ) & 0x03 ) << 28
            x |= ( UInt32( expanded_img[(i * 16) - 15] ) & 0x03 ) << 30

            chars[i] = x

        end

        #pretty_print(chars)
        char_count = chars[1]
        if( args["out_file"] == nothing )
            for i in 2:length(chars)
                print(Char(chars[i]))
                if(i > char_count)
                    break
                end
            end
            println()
        else
            save_file = open(args["out_file"], "w+")
            seek(save_file, 0)
            for i in 2:length(chars)
                write(save_file, Char(chars[i]))
                if(i > char_count)
                    break
                end
            end
            flush(save_file)
            println()
        end
    ################################################################################
    elseif(file_type == 0x01)
    
    elseif(file_type == 0x02)
    ################################################################################
        chars = zeros(UInt8, length(expanded_img) ÷ 4)

        #pretty_print(chars)
    
        char_count = UInt32(0)
        char_count|= ( UInt32( expanded_img[16] ) ) & 0x03 
        char_count|= ( UInt32( expanded_img[15] ) & 0x03 ) << 2
        char_count|= ( UInt32( expanded_img[14] ) & 0x03 ) << 4
        char_count|= ( UInt32( expanded_img[13] ) & 0x03 ) << 6
        char_count|= ( UInt32( expanded_img[12] ) & 0x03 ) << 8
        char_count|= ( UInt32( expanded_img[11] ) & 0x03 ) << 10
        char_count|= ( UInt32( expanded_img[10] ) & 0x03 ) << 12
        char_count|= ( UInt32( expanded_img[9] ) & 0x03 ) << 14
        char_count|= ( UInt32( expanded_img[8] ) & 0x03 ) << 16
        char_count|= ( UInt32( expanded_img[7] ) & 0x03 ) << 18
        char_count|= ( UInt32( expanded_img[6] ) & 0x03 ) << 20
        char_count|= ( UInt32( expanded_img[5] ) & 0x03 ) << 22
        char_count|= ( UInt32( expanded_img[4] ) & 0x03 ) << 24
        char_count|= ( UInt32( expanded_img[3] ) & 0x03 ) << 26
        char_count|= ( UInt32( expanded_img[2] ) & 0x03 ) << 28
        char_count|= ( UInt32( expanded_img[1] ) & 0x03 ) << 30
    
        for i in 5:length(chars)
    
            x = UInt8(0)
    
            x |= ( expanded_img[i * 4] ) & 0x03 
            x |= ( expanded_img[(i * 4) - 1] & 0x03 ) << 2
            x |= ( expanded_img[(i * 4) - 2] & 0x03 ) << 4
            x |= ( expanded_img[(i * 4) - 3] & 0x03 ) << 6
    
            chars[i - 4] = x
    
        end
    
        #pretty_print(chars)
        if( args["out_file"] == nothing )
            println(".pdf requires output file")
        else
            save_file = open(args["out_file"], "w+")
            seek(save_file, 0)
            for i in 1:length(chars)
                write(save_file, chars[i])
                if(i > char_count)
                    break
                end
            end
            flush(save_file)
            println()
        end
    ################################################################################
    elseif(file_type == 0x03)

    end

end

function parse_args()#::Dict{Symbol,Any}

    @beginarguments begin

        @argumentflag encode "-e"
        @argumentflag decode "-d"
        @argumentoptional String out_file "-o"
        @positionalrequired String in_file
        @positionaloptional String hidden

    end

    #println("encode: $encode - decode: $decode\nout_file: $out_file - in_file: $in_file\nhidden: $hidden")

    ret = Dict("encode" =>encode, "decode" => decode, "out_file" => out_file, "in_file" => in_file, "hidden" => hidden)
end

function validate_args(args::Dict)

    if( (args["encode"]) && (args["decode"]) )
        return false
    end

    if( (args["encode"]) && (args["hidden"] == nothing) )
        return false
    end

    if( (args["decode"]) && (args["hidden"] != nothing) )
        return false
    end

    return( xor( args["encode"], args["decode"] ) )

end

flags = parse_args()

if(!( validate_args(flags) ))
    println("INVALID OPTIONS") #TODO: better error message
    exit(0)
end

s = get_ext(flags["hidden"])
println(s)

if(flags["decode"])
    decode(flags)
elseif(flags["encode"])
    encode_driver(s, flags)
end