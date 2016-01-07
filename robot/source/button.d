import dsfml.graphics;

class Button : Drawable, Transformable
{
    mixin NormalTransformable;
    
    private
    {
        RectangleShape m_backgroundShape;
        Text m_text;
    }
    
    this(string text, const(Font) font, uint characterSize = 30)
    {
        m_text = new Text(text, font, characterSize);
        auto bounds = m_text.getLocalBounds();
        m_text.origin = Vector2f(bounds.width/2, bounds.height/2);
        m_backgroundShape = new RectangleShape(Vector2f(bounds.width, bounds.height));
        m_backgroundShape.origin = Vector2f(bounds.width/2, bounds.height/2);
    }
    
    void setBackgroundColor(Color c)
    {
        m_backgroundShape.fillColor = c;
    }
    
    void setColor(Color c)
    {
        m_text.setColor = c;
    }
    
    FloatRect getGlobalBounds()
	{
		return getTransform().transformRect(getLocalBounds());
	}

	FloatRect getLocalBounds()
	{
		return m_backgroundShape.getLocalBounds();
	}
    
    override void draw(RenderTarget renderTarget, RenderStates renderStates)
	{
        renderStates.transform *= getTransform();
		renderTarget.draw(m_backgroundShape, renderStates);
    	renderTarget.draw(m_text, renderStates);
	}
    
}