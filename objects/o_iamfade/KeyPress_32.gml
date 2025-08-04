/// @description
if (!first)
{
	scurve.Play();
	first = true;
}
else
{
	if (!scurve.IsReversed() )
	{
		scurve.Reverse(true).Play();
	}	
	else
	{
		scurve.Reverse(false).Play();	
	}
}

