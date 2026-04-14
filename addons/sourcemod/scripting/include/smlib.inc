#if defined _smlib_included
	#endinput
#endif
#define _smlib_included

#define HalfHumanHeight 36.0

stock int Math_GetRandomInt(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

stock float Math_GetRandomFloat(float min, float max)
{
	return GetURandomFloat() * (max - min) + min;
}

stock void Array_Copy(const any[] source, any[] destination, int size)
{
	for (int i = 0; i < size; i++)
	{
		destination[i] = source[i];
	}
}

stock void Array_Fill(any[] array, int size, any value)
{
	for (int i = 0; i < size; i++)
	{
		array[i] = value;
	}
}
