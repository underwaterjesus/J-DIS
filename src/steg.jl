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

function encode(args::Dict)
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

    if( filesize(doc) * 16 > 3(n * m) )
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

    chars = Array{UInt32,1}(undef, filesize(doc))
    i = 0
    while(!(eof(doc)))
        i += 1
        global chr = read(doc, Char)
        chars[i] = UInt32(chr)
    end

    #pretty_print(chars)

    #=
    a::UInt8  = 0x00
    b::UInt8  = 0x00
    c::UInt8  = 0x00
    d::UInt8  = 0x00
    =#

    for i in 1:length(chars)

        a = UInt8( chars[i] & 0x03 )
        b = UInt8( (chars[i] >> 2) & 0x03 )
        c = UInt8( (chars[i] >> 4) & 0x03 )
        d = UInt8( (chars[i] >> 6) & 0x03 )
        e = UInt8( (chars[i] >> 8) & 0x03 )
        f = UInt8( (chars[i] >> 10) & 0x03 )
        g = UInt8( (chars[i] >> 12) & 0x03 )
        h = UInt8( (chars[i] >> 14) & 0x03 )
        i_ = UInt8( (chars[i] >> 16) & 0x03 )
        j = UInt8( (chars[i] >> 18) & 0x03 )
        k = UInt8( (chars[i] >> 20) & 0x03 )
        l = UInt8( (chars[i] >> 22) & 0x03 )
        m_ = UInt8( (chars[i] >> 24) & 0x03 )
        n_ = UInt8( (chars[i] >> 26) & 0x03 )
        o = UInt8( (chars[i] >> 28) & 0x03 )
        p = UInt8( (chars[i] >> 30) & 0x03 )

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
        expanded_img[i*16-10] = expanded_img[i*16-10] | n_
        expanded_img[i*16-11] = expanded_img[i*16-11] | o
        expanded_img[i*16-12] = expanded_img[i*16-12] | p

    end

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

    chars = zeros(UInt32, length(expanded_img) ÷ 16)

    #pretty_print(chars)

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

    if( args["out_file"] == nothing )
        for i in 1:length(chars)
            print(Char(chars[i]))
        end
        println()
    else
        save_file = open(args["out_file"], "w+")
        seek(save_file, 0)
        for i in 1:length(chars)
            write(save_file, Char(chars[i]))
        end
        flush(save_file)
        println()
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

if(flags["decode"])
    decode(flags)
elseif(flags["encode"])
    encode(flags)
end